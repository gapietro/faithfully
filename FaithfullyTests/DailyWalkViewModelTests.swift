import XCTest
import SwiftData
@testable import Faithfully

final class DailyWalkViewModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var badgeService: BadgeService!
    var challengeService: ChallengeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        badgeService = BadgeService(modelContext: context)
        challengeService = try ChallengeService(modelContext: context, challenges: challenges, badgeService: badgeService)
    }

    func testInitLoadsTodaysChallenge() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        let expected = challengeService.challengeForDate(today)
        XCTAssertEqual(vm.todayChallenge.id, expected.id)
    }

    func testIsCompletedReflectsActualCompletionState() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        XCTAssertFalse(vm.isCompleted)
    }

    func testCurrentStreakReflectsCalculatedStreak() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        XCTAssertEqual(vm.currentStreak, 0)
    }

    func testCompleteCallsChallengeServiceCompleteChallenge() throws {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)

        // Verify completion was persisted
        let descriptor = FetchDescriptor<CompletedChallenge>()
        let completions = try context.fetch(descriptor)
        XCTAssertEqual(completions.count, 1)
    }

    func testCompleteUpdatesIsCompletedToTrue() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertTrue(vm.isCompleted)
    }

    func testCompleteUpdatesCurrentStreak() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertEqual(vm.currentStreak, 1)
    }

    func testCompleteSetsNewBadgesIfBadgesAwarded() throws {
        let today = Date.now
        // Insert 30 prior completions so the 31st triggers 5K badge
        for i in 1...30 {
            let date = today.addingDays(-i)
            let challenge = challengeService.challengeForDate(date)
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date
            )
            context.insert(completion)
        }
        try context.save()

        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertFalse(vm.newBadges.isEmpty, "Should have new badges after 31 completions")
    }

    func testCompleteSetsShowCelebrationIfBadgesAwarded() throws {
        let today = Date.now
        for i in 1...30 {
            let date = today.addingDays(-i)
            let challenge = challengeService.challengeForDate(date)
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date
            )
            context.insert(completion)
        }
        try context.save()

        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertTrue(vm.showCelebration)
    }

    func testDayRolloverClearsCelebrationState() throws {
        let today = Date.now
        for i in 1...30 {
            let date = today.addingDays(-i)
            let challenge = challengeService.challengeForDate(date)
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date
            )
            context.insert(completion)
        }
        try context.save()

        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertTrue(vm.showCelebration)

        vm.refresh(for: today.addingDays(1))
        XCTAssertFalse(vm.showCelebration,
                       "A celebration left open overnight must not block the new day's UI")
        XCTAssertTrue(vm.newBadges.isEmpty)
    }

    func testSameDayRefreshPreservesCelebrationState() throws {
        let today = Date.now
        for i in 1...30 {
            let date = today.addingDays(-i)
            let challenge = challengeService.challengeForDate(date)
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date
            )
            context.insert(completion)
        }
        try context.save()

        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertTrue(vm.showCelebration)

        vm.refresh(for: today)
        XCTAssertTrue(vm.showCelebration,
                      "A same-day refresh must not dismiss a celebration mid-show")
        XCTAssertFalse(vm.newBadges.isEmpty)
    }

    func testTranslationChangeUpdatesScriptureText() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        let webText = vm.scriptureText
        XCTAssertEqual(webText, vm.todayChallenge.scriptureText(for: .web))

        vm.updateTranslation(.kjv)
        XCTAssertEqual(vm.scriptureText, vm.todayChallenge.scriptureText(for: .kjv))
        XCTAssertEqual(vm.translation, .kjv)
    }

    // MARK: - Completion reports its outcome (CLEAN-003)

    /// Lets a test force any failure the real service can produce, including a
    /// persistence failure, which an in-memory store will not reproduce.
    private final class StubChallengeService: ChallengeServiceProtocol {
        let enrollmentDate: Date
        private let challenge: DailyChallenge
        var errorToThrow: Error?
        private(set) var receivedJournals: [String?] = []

        init(enrollmentDate: Date, challenge: DailyChallenge) {
            self.enrollmentDate = enrollmentDate
            self.challenge = challenge
        }

        func loadChallenges() -> [DailyChallenge] { [challenge] }
        func challengeForDate(_ date: Date) -> DailyChallenge { challenge }
        func isCompleted(on scheduledDate: Date) -> Bool { false }
        func fetchCompletions(for dateRange: ClosedRange<Date>) -> [CompletedChallenge] { [] }
        func fetchAllCompletions() -> [CompletedChallenge] { [] }
        func calculateStreak() -> Int { 0 }

        func completeChallenge(
            _ challenge: DailyChallenge, on scheduledDate: Date, journal: String?
        ) throws -> [BadgeDefinition] {
            receivedJournals.append(journal)
            if let errorToThrow { throw errorToThrow }
            return []
        }
    }

    private func makeStubbedViewModel() throws -> (DailyWalkViewModel, StubChallengeService) {
        let today = Date.now
        let stub = StubChallengeService(
            enrollmentDate: TestHelpers.longEnrolledDate,
            challenge: try XCTUnwrap(challenges.first)
        )
        return (DailyWalkViewModel(challengeService: stub, today: today), stub)
    }

    func testCompleteReturnsCompletedOnSuccess() throws {
        let (vm, _) = try makeStubbedViewModel()
        let result = vm.complete(journal: "It went well")

        XCTAssertEqual(result, .completed(newBadges: []))
        XCTAssertTrue(result.isCompleted)
        XCTAssertTrue(vm.isCompleted)
    }

    func testCompleteReportsAnOverLongJournalWithoutMarkingTheDayDone() throws {
        let (vm, stub) = try makeStubbedViewModel()
        stub.errorToThrow = ChallengeServiceError.journalTooLong(
            limit: Constants.maxJournalLength, actual: Constants.maxJournalLength + 1
        )

        let result = vm.complete(journal: String(repeating: "a", count: Constants.maxJournalLength + 1))

        XCTAssertEqual(result, .failed(.journalTooLong(
            limit: Constants.maxJournalLength, actual: Constants.maxJournalLength + 1
        )))
        XCTAssertFalse(vm.isCompleted,
                       "A rejected journal must leave the day open so the user can fix and retry")
    }

    /// The draft-loss half of CLEAN-003: when the save fails, the view model must
    /// say so, because the caller keeps the editor open on anything but success.
    func testCompleteReportsCouldNotSaveWhenPersistenceFails() throws {
        struct DiskFull: Error {}
        let (vm, stub) = try makeStubbedViewModel()
        stub.errorToThrow = DiskFull()

        let result = vm.complete(journal: "Something I do not want to lose")

        XCTAssertEqual(result, .failed(.couldNotSave))
        XCTAssertFalse(result.isCompleted,
                       "The caller must not treat a failed save as success and clear the draft")
        XCTAssertFalse(vm.isCompleted)
    }

    func testFailureMessagesAreUserFacingAndNonEmpty() {
        let failures: [CompletionFailure] = [
            .journalTooLong(limit: 2000, actual: 2001),
            .beforeEnrollment,
            .gracePeriodExpired,
            .alreadyCompleted,
            .couldNotSave
        ]
        for failure in failures {
            XCTAssertFalse(failure.message.isEmpty, "\(failure) needs a message the user can read")
        }
        XCTAssertTrue(
            CompletionFailure.journalTooLong(limit: 2000, actual: 2001).message.contains("1 character"),
            "The over-limit message must be singular for exactly one character over"
        )
        XCTAssertTrue(
            CompletionFailure.couldNotSave.message.contains("still here"),
            "A failed save must reassure the user their draft survives"
        )
    }

    func testCompletingAnAlreadyCompletedDayReportsRatherThanSilentlyDoingNothing() throws {
        let (vm, _) = try makeStubbedViewModel()
        XCTAssertTrue(vm.complete(journal: nil).isCompleted)

        let second = vm.complete(journal: nil)
        XCTAssertEqual(second, .failed(.alreadyCompleted))
    }
}
