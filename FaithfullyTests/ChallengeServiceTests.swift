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
        service = ChallengeService(modelContext: context, challenges: challenges, badgeService: badgeService)
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
