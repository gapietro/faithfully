import XCTest
import SwiftData
@testable import Faithfully

/// Wraps a real coordinator so a test can make any single operation fail.
///
/// An in-memory store never fails, which is exactly why these paths were
/// untested and why `try?` looked harmless: the failure branch was unreachable
/// in tests and reachable only on a user's device.
final class InjectablePersistence: PersistenceCoordinating {
    private let wrapped: PersistenceCoordinator

    var failNextSave = false
    var failEverySave = false
    var failFetch = false
    private(set) var saveCount = 0
    private(set) var rollbackCount = 0

    init(context: ModelContext) {
        self.wrapped = PersistenceCoordinator(context: context)
    }

    var context: ModelContext { wrapped.context }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        if failFetch { throw PersistenceError.fetchFailed("injected") }
        return try wrapped.fetch(descriptor)
    }

    func insert<T: PersistentModel>(_ model: T) {
        wrapped.insert(model)
    }

    func save() throws {
        saveCount += 1
        if failEverySave || failNextSave {
            failNextSave = false
            throw PersistenceError.saveFailed("injected")
        }
        try wrapped.save()
    }

    func rollback() {
        rollbackCount += 1
        wrapped.rollback()
    }
}

final class PersistenceFailureTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var persistence: InjectablePersistence!
    var badgeService: BadgeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        persistence = InjectablePersistence(context: context)
        badgeService = BadgeService(persistence: persistence)
    }

    private func makeChallengeService(today: Date) throws -> ChallengeService {
        try ChallengeService(
            persistence: persistence,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: TestHelpers.longEnrolledDate,
            dateProvider: { today }
        )
    }

    // MARK: - Completion save failure

    func testFailedCompletionSaveReportsTheFailure() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeChallengeService(today: today)
        persistence.failNextSave = true

        XCTAssertThrowsError(
            try service.completeChallenge(service.challengeForDate(today), on: today, journal: "kept?")
        ) { error in
            XCTAssertEqual(error as? PersistenceError, .saveFailed("injected"))
        }
    }

    func testFailedCompletionSaveLeavesNothingBehind() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeChallengeService(today: today)
        persistence.failNextSave = true

        _ = try? service.completeChallenge(service.challengeForDate(today), on: today, journal: "kept?")

        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletedChallenge>()).count, 0,
                       "A failed save must not leave a completion in the store")
        XCTAssertFalse(service.isCompleted(on: today),
                       "The day must remain completable so the user can retry")
        XCTAssertEqual(persistence.rollbackCount, 1, "The transaction must roll back")
    }

    func testFailedCompletionSaveDoesNotLeaveAnInMemoryGhost() throws {
        // Rollback has to clear the *context*, not just skip the write. A lingering
        // unsaved insert would be committed later by an unrelated save.
        let today = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeChallengeService(today: today)
        persistence.failNextSave = true
        _ = try? service.completeChallenge(service.challengeForDate(today), on: today, journal: "ghost")

        // A later, successful write must not drag the rolled-back row in with it.
        let laterDay = Date.from(year: 2026, month: 6, day: 16)
        let laterService = try makeChallengeService(today: laterDay)
        _ = try laterService.completeChallenge(
            laterService.challengeForDate(laterDay), on: laterDay, journal: "real"
        )

        let stored = try context.fetch(FetchDescriptor<CompletedChallenge>())
        XCTAssertEqual(stored.count, 1, "Only the successful completion may exist")
        XCTAssertEqual(stored.first?.journalEntry, "real")
    }

    // MARK: - Completion and badges are atomic

    /// The interruption the audit described: the process dies (or the write
    /// fails) between saving the completion and saving the badges it earned.
    /// With two transactions the completion survived without its badge.
    func testCompletionAndItsBadgesCommitAsOneUnit() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeChallengeService(today: today)

        // 30 prior completions, so the 31st earns the 5K journey badge.
        for offset in 1...30 {
            let date = today.addingDays(-offset)
            let challenge = service.challengeForDate(date)
            context.insert(CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date.startOfDay
            ))
        }
        try context.save()

        persistence.failNextSave = true
        _ = try? service.completeChallenge(service.challengeForDate(today), on: today, journal: nil)

        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletedChallenge>()).count, 30,
                       "The completion must not survive the failed save")
        XCTAssertTrue(try context.fetch(FetchDescriptor<EarnedBadge>()).isEmpty,
                      "Nor may the badge it would have earned")
    }

    func testSuccessfulCompletionCommitsTheBadgeInTheSameTransaction() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeChallengeService(today: today)
        for offset in 1...30 {
            let date = today.addingDays(-offset)
            let challenge = service.challengeForDate(date)
            context.insert(CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date.startOfDay
            ))
        }
        try context.save()

        let before = persistence.saveCount
        let badges = try service.completeChallenge(service.challengeForDate(today), on: today, journal: nil)

        XCTAssertTrue(badges.contains { $0.id == "journey_5k" })
        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletedChallenge>()).count, 31)
        XCTAssertEqual(try context.fetch(FetchDescriptor<EarnedBadge>()).count, 1)
        XCTAssertEqual(persistence.saveCount - before, 1,
                       "Completion and badges must commit in one save, not two")
    }

    // MARK: - Launch reconciliation

    func testLaunchReconcilesBadgesForCompletionsThatNeverEarnedThem() throws {
        // Simulates the pre-fix damage: completions on disk with no badge rows,
        // as a process death between the two old saves would leave behind.
        let today = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeChallengeService(today: today)
        for offset in 0..<31 {
            let date = today.addingDays(-offset)
            let challenge = service.challengeForDate(date)
            context.insert(CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date.startOfDay
            ))
        }
        try context.save()
        XCTAssertTrue(try context.fetch(FetchDescriptor<EarnedBadge>()).isEmpty)

        _ = AppEnvironment(
            persistence: persistence,
            loadChallenges: { self.challenges },
            notificationService: NotificationService(center: MockNotificationCenter()),
            dateProvider: { today }
        )

        let earned = try context.fetch(FetchDescriptor<EarnedBadge>())
        XCTAssertTrue(earned.contains { $0.badgeName == "journey_5k" },
                      "Launch must repair a badge the completions had already earned")
    }

    func testLaunchReconciliationIsIdempotent() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeChallengeService(today: today)
        for offset in 0..<31 {
            let date = today.addingDays(-offset)
            let challenge = service.challengeForDate(date)
            context.insert(CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date.startOfDay
            ))
        }
        try context.save()

        for _ in 0..<3 {
            _ = AppEnvironment(
                persistence: persistence,
                loadChallenges: { self.challenges },
                notificationService: NotificationService(center: MockNotificationCenter()),
                dateProvider: { today }
            )
        }

        let names = try context.fetch(FetchDescriptor<EarnedBadge>()).map(\.badgeName)
        XCTAssertEqual(Set(names).count, names.count, "Repeated launches must not duplicate badges")
    }

    // MARK: - Startup fetch failure

    func testProfileFetchFailureFailsClosedInsteadOfCreatingASecondProfile() throws {
        try context.save()
        context.insert(UserProfile(startDate: TestHelpers.longEnrolledDate))
        try context.save()

        persistence.failFetch = true
        let env = AppEnvironment(
            persistence: persistence,
            loadChallenges: { self.challenges },
            notificationService: NotificationService(center: MockNotificationCenter()),
            dateProvider: { Date.from(year: 2026, month: 6, day: 15) }
        )

        guard case .failed(let message) = env.state else {
            return XCTFail("A failed profile read must fail closed, got \(env.state)")
        }
        XCTAssertEqual(message, PersistenceError.fetchFailed("injected").message)
        XCTAssertNil(env.services)
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).count, 1,
                       "A read failure must never mint a second profile")
    }

    // MARK: - Settings

    func testFailedSettingsSaveRevertsTheDisplayedValue() throws {
        let profile = UserProfile()
        persistence.insert(profile)
        try persistence.save()
        let vm = SettingsViewModel(persistence: persistence, profile: profile)
        XCTAssertEqual(vm.translation, .web)

        persistence.failNextSave = true
        vm.updateTranslation(.kjv)

        XCTAssertEqual(vm.translation, .web,
                       "The UI must not show a preference that was never written")
        XCTAssertEqual(profile.preferredTranslation, .web,
                       "Nor may the model keep the rejected value")
        XCTAssertNotNil(vm.saveError)
    }

    func testFailedSettingsSaveDoesNotAnnounceAChangeThatDidNotHappen() throws {
        let profile = UserProfile()
        persistence.insert(profile)
        try persistence.save()
        let vm = SettingsViewModel(persistence: persistence, profile: profile)

        var notified = 0
        vm.onPreferencesChanged = { notified += 1 }

        persistence.failNextSave = true
        vm.toggleMorningNotifications(false)
        XCTAssertEqual(notified, 0,
                       "A failed save must not reschedule notifications from a value that was rejected")
        XCTAssertTrue(vm.morningEnabled)

        vm.toggleMorningNotifications(false)
        XCTAssertEqual(notified, 1, "A subsequent successful save must announce normally")
        XCTAssertFalse(vm.morningEnabled)
        XCTAssertNil(vm.saveError, "A success must clear the previous error")
    }

    // MARK: - Store recovery

    @MainActor
    func testDegradedStoreStillYieldsAUsableContainerAndReportsTheFailure() {
        // The pre-fix behaviour was `fatalError` in `App.init`: an unopenable
        // store crash-looped before any UI existed, so the user could never be
        // told, and their only recourse was deleting the app and their journal.
        switch PersistenceStack.open() {
        case .ready(let container):
            let context = container.mainContext
            XCTAssertNoThrow(try context.fetch(FetchDescriptor<UserProfile>()))
        case .degraded(let container, let error):
            let context = container.mainContext
            XCTAssertNoThrow(try context.fetch(FetchDescriptor<UserProfile>()),
                             "A degraded stack must still hand back a working container")
            XCTAssertFalse(error.message.isEmpty)
        }
    }

    func testStoreUnavailableMessageTellsTheUserWhatStillWorks() {
        let message = PersistenceError.storeUnavailable("whatever").message
        XCTAssertTrue(message.contains("challenges still work"),
                      "The banner must say what survives, not just that something broke")
        XCTAssertTrue(message.contains("can't be read or written"),
                      "and must be explicit that changes are not being saved")
    }
}
