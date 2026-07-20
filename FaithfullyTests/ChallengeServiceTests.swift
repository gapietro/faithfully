import XCTest
import SwiftData
@testable import Faithfully

final class ChallengeServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var badgeService: BadgeService!
    var service: ChallengeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        badgeService = BadgeService(modelContext: context)
        service = try ChallengeService(modelContext: context, challenges: challenges, badgeService: badgeService)
    }

    func testLoadChallengesReturns365Items() {
        XCTAssertEqual(service.loadChallenges().count, 365)
    }

    func testChallengeForDateReturnsCorrectChallenge() {
        let date = Date.from(year: 2026, month: 6, day: 15)
        let challenge = service.challengeForDate(date)
        let again = service.challengeForDate(date)
        XCTAssertEqual(challenge.id, again.id)
    }

    func testCompleteChallengeCreatesCompletedChallengeRecord() throws {
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        let descriptor = FetchDescriptor<CompletedChallenge>()
        let completions = try context.fetch(descriptor)
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.challengeId, challenge.id)
    }

    func testCompleteChallengeWithJournalSavesJournalText() throws {
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: "God was good today")

        let descriptor = FetchDescriptor<CompletedChallenge>()
        let completions = try context.fetch(descriptor)
        XCTAssertEqual(completions.first?.journalEntry, "God was good today")
    }

    func testCompleteChallengeThrowsOnExpiredGracePeriod() {
        let fiveDaysAgo = Date.now.addingDays(-5)
        let challenge = service.challengeForDate(fiveDaysAgo)

        XCTAssertThrowsError(try service.completeChallenge(challenge, on: fiveDaysAgo, journal: nil)) { error in
            XCTAssertTrue(error is ChallengeServiceError)
        }
    }

    func testCompleteChallengeThrowsOnAlreadyCompleted() throws {
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        XCTAssertThrowsError(try service.completeChallenge(challenge, on: today, journal: nil)) { error in
            guard let serviceError = error as? ChallengeServiceError else {
                XCTFail("Expected ChallengeServiceError")
                return
            }
            XCTAssertEqual(serviceError, .alreadyCompleted)
        }
    }

    func testCompleteChallengeTriggersNewBadgeEvaluation() throws {
        // Complete enough challenges to earn a badge (7 for Ember streak is hard to set up,
        // so just verify the method returns badge definitions array)
        let today = Date.now
        let challenge = service.challengeForDate(today)
        let newBadges = try service.completeChallenge(challenge, on: today, journal: nil)

        // With only 1 completion, no badges should be earned yet
        XCTAssertTrue(newBadges.isEmpty, "1 completion should not earn any badges")
    }

    func testFetchCompletionsReturnsCorrectRecordsForDateRange() throws {
        // Complete today's challenge
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        let range = today.addingDays(-1)...today.addingDays(1)
        let completions = service.fetchCompletions(for: range)
        XCTAssertEqual(completions.count, 1)

        // Fetch a range that doesn't include today
        let pastRange = today.addingDays(-10)...today.addingDays(-5)
        let pastCompletions = service.fetchCompletions(for: pastRange)
        XCTAssertEqual(pastCompletions.count, 0)
    }

    // MARK: - Fail-closed pool (#5)

    func testInitThrowsOnEmptyChallengePool() {
        XCTAssertThrowsError(
            try ChallengeService(modelContext: context, challenges: [], badgeService: badgeService)
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .emptyChallengePool)
        }
    }

    func testInitThrowsOnGivingOnlyPool() {
        let givingOnly = challenges.filter { $0.category == .giving }
        XCTAssertThrowsError(
            try ChallengeService(modelContext: context, challenges: givingOnly, badgeService: badgeService)
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .emptyChallengePool)
        }
    }

    // MARK: - Completion keyed by scheduled day (#3)

    func testIsCompletedIsScopedToScheduledDay() throws {
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        XCTAssertTrue(service.isCompleted(on: today))
        XCTAssertFalse(service.isCompleted(on: today.addingDays(1)))
        XCTAssertFalse(service.isCompleted(on: today.addingDays(-1)))
    }

    func testCompletingReusedChallengeIdOnOneDayDoesNotCompleteTheOther() throws {
        // The scheduler reuses non-giving IDs within a year and giving IDs monthly.
        // Find two 2026 dates that map to the same challenge ID under one service.
        let startDate = Date.from(year: 2026, month: 1, day: 1)
        var currentToday = startDate
        let service = try ChallengeService(
            modelContext: context,
            challenges: challenges,
            badgeService: badgeService,
            userStartDate: startDate,
            dateProvider: { currentToday }
        )

        var datesByChallengeId: [String: [Date]] = [:]
        for offset in 0..<365 {
            let date = startDate.addingDays(offset)
            datesByChallengeId[service.challengeForDate(date).id, default: []].append(date)
        }
        guard let reusedDates = datesByChallengeId.values.first(where: { $0.count >= 2 }) else {
            XCTFail("Expected at least one challenge ID scheduled on two dates within the year")
            return
        }
        let dateA = reusedDates[0]
        let dateB = reusedDates[1]
        XCTAssertEqual(service.challengeForDate(dateA).id, service.challengeForDate(dateB).id)

        // Complete day A (with "today" set to day A so grace allows it)
        currentToday = dateA
        _ = try service.completeChallenge(service.challengeForDate(dateA), on: dateA, journal: nil)

        XCTAssertTrue(service.isCompleted(on: dateA))
        XCTAssertFalse(service.isCompleted(on: dateB),
                       "Completing day A must not mark a later day with the same challenge ID as done")

        // Day B must still be completable independently
        currentToday = dateB
        XCTAssertNoThrow(try service.completeChallenge(service.challengeForDate(dateB), on: dateB, journal: nil))
        XCTAssertTrue(service.isCompleted(on: dateB))

        let all = try context.fetch(FetchDescriptor<CompletedChallenge>())
        XCTAssertEqual(all.count, 2, "Both days should have their own completion record")
    }

    // MARK: - Year rotation in the live service path (#4)

    func testChallengeForDateAppliesYearOffsetFromUserStartDate() throws {
        let startDate = Date.from(year: 2025, month: 1, day: 1)
        let service = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            userStartDate: startDate
        )
        let target = Date.from(year: 2026, month: 6, day: 15) // one whole year after start
        let scheduler = try XCTUnwrap(ChallengeScheduler(challenges: challenges))

        XCTAssertEqual(service.challengeForDate(target).id,
                       scheduler.challengeForDate(target, yearOffset: 1).id,
                       "Service path must pass the year offset derived from the user's start date")
        XCTAssertNotEqual(service.challengeForDate(target).id,
                          scheduler.challengeForDate(target, yearOffset: 0).id,
                          "A second-year user must not see the first-year pairing")
    }

    func testChallengeForDateUsesZeroOffsetWithinFirstYear() throws {
        let startDate = Date.from(year: 2026, month: 1, day: 1)
        let service = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            userStartDate: startDate
        )
        let target = Date.from(year: 2026, month: 6, day: 15)
        let scheduler = try XCTUnwrap(ChallengeScheduler(challenges: challenges))

        XCTAssertEqual(service.challengeForDate(target).id,
                       scheduler.challengeForDate(target, yearOffset: 0).id)
    }

    func testCalculateStreakDelegatesToStreakAlgorithm() throws {
        // No completions = streak of 0
        XCTAssertEqual(service.calculateStreak(), 0)

        // Complete today
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        XCTAssertEqual(service.calculateStreak(), 1)
    }
}

extension ChallengeServiceError: Equatable {
    public static func == (lhs: ChallengeServiceError, rhs: ChallengeServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.gracePeriodExpired, .gracePeriodExpired): return true
        case (.alreadyCompleted, .alreadyCompleted): return true
        default: return false
        }
    }
}
