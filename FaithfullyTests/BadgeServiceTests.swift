import XCTest
import SwiftData
@testable import Faithfully

final class BadgeServiceTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var service: BadgeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        service = BadgeService(modelContext: context)
    }

    func testAllBadgeDefinitionsReturnsAllJourneyStreakAndCategoryBadges() {
        let all = service.allBadgeDefinitions()
        let journeyCount = 5
        let streakCount = 5
        let categoryCount = 10 * 4 // 10 categories x 4 levels
        XCTAssertEqual(all.count, journeyCount + streakCount + categoryCount)
    }

    func testProgressForUnearnedBadgeShowsCorrectNumeratorDenominator() {
        let badge = BadgeDefinition.journey5K
        let progress = service.progress(for: badge)
        XCTAssertEqual(progress.current, 0)
        XCTAssertEqual(progress.definition.threshold, 31)
        XCTAssertFalse(progress.isEarned)
        XCTAssertNil(progress.earnedDate)
        XCTAssertEqual(progress.progress, 0.0)
    }

    func testProgressForEarnedBadgeShows100Percent() throws {
        // Manually insert an earned badge
        let earned = EarnedBadge(
            badgeName: "journey_5k",
            badgeType: .journey,
            threshold: 31
        )
        context.insert(earned)
        try context.save()

        // Also insert 31 completions to make progress = 100%
        for i in 0..<31 {
            let completion = CompletedChallenge(
                challengeId: "challenge_\(String(format: "%03d", i + 1))",
                challengeCategory: "prayer",
                completedDate: Date.now.addingDays(-i),
                scheduledDate: Date.now.addingDays(-i)
            )
            context.insert(completion)
        }
        try context.save()

        let badge = BadgeDefinition.journey5K
        let progress = service.progress(for: badge)
        XCTAssertTrue(progress.isEarned)
        XCTAssertEqual(progress.progress, 1.0)
        XCTAssertNotNil(progress.earnedDate)
    }

    func testEarnedBadgesReturnsAllBadgesFromSwiftData() throws {
        let badge1 = EarnedBadge(badgeName: "journey_5k", badgeType: .journey, threshold: 31)
        let badge2 = EarnedBadge(badgeName: "streak_ember", badgeType: .streak, threshold: 7)
        context.insert(badge1)
        context.insert(badge2)
        try context.save()

        let earned = service.earnedBadges()
        XCTAssertEqual(earned.count, 2)
    }

    func testEvaluateAndAwardPersistsNewBadges() throws {
        // Insert 31 completions to earn 5K badge
        for i in 0..<31 {
            let completion = CompletedChallenge(
                challengeId: "challenge_\(String(format: "%03d", i + 1))",
                challengeCategory: "prayer",
                completedDate: Date.now.addingDays(-i),
                scheduledDate: Date.now.addingDays(-i)
            )
            context.insert(completion)
        }
        try context.save()

        let newBadges = service.evaluateAndStageAwards()
        XCTAssertTrue(newBadges.contains(where: { $0.id == "journey_5k" }))

        // Verify persisted
        let earned = service.earnedBadges()
        XCTAssertTrue(earned.contains(where: { $0.badgeName == "journey_5k" }))
    }

    func testEvaluateAndAwardDoesNotDuplicateExistingBadges() throws {
        // Pre-insert earned badge
        let existing = EarnedBadge(badgeName: "journey_5k", badgeType: .journey, threshold: 31)
        context.insert(existing)

        // Insert 31 completions
        for i in 0..<31 {
            let completion = CompletedChallenge(
                challengeId: "challenge_\(String(format: "%03d", i + 1))",
                challengeCategory: "prayer",
                completedDate: Date.now.addingDays(-i),
                scheduledDate: Date.now.addingDays(-i)
            )
            context.insert(completion)
        }
        try context.save()

        let newBadges = service.evaluateAndStageAwards()
        XCTAssertFalse(newBadges.contains(where: { $0.id == "journey_5k" }),
                       "Should not re-award existing badge")

        // Should still be only 1 earned badge entry
        let earned = service.earnedBadges()
        let fiveKBadges = earned.filter { $0.badgeName == "journey_5k" }
        XCTAssertEqual(fiveKBadges.count, 1, "Should not duplicate badge")
    }
}
