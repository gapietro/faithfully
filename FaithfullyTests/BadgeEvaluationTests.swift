import XCTest
@testable import Faithfully

final class BadgeEvaluationTests: XCTestCase {

    func testZeroCompletionsEarnsNoBadges() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 0,
            currentStreak: 0,
            categoryCounts: [:],
            earnedBadgeNames: []
        )
        XCTAssertTrue(badges.isEmpty)
    }

    func test31CompletionsEarns5KJourneyBadge() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 31,
            currentStreak: 0,
            categoryCounts: [:],
            earnedBadgeNames: []
        )
        XCTAssertTrue(badges.contains(where: { $0.name == "5K" }))
    }

    func test90CompletionsEarns10KAndStillHas5K() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 90,
            currentStreak: 0,
            categoryCounts: [:],
            earnedBadgeNames: []
        )
        XCTAssertTrue(badges.contains(where: { $0.name == "5K" }))
        XCTAssertTrue(badges.contains(where: { $0.name == "10K" }))
    }

    func test365CompletionsEarnsMarathon() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 365,
            currentStreak: 0,
            categoryCounts: [:],
            earnedBadgeNames: []
        )
        XCTAssertTrue(badges.contains(where: { $0.name == "Marathon" }))
    }

    func test7DayStreakEarnsEmber() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 7,
            currentStreak: 7,
            categoryCounts: [:],
            earnedBadgeNames: []
        )
        XCTAssertTrue(badges.contains(where: { $0.name == "Ember" }))
    }

    func test30DayStreakEarnsFlameAndStillHasEmber() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 30,
            currentStreak: 30,
            categoryCounts: [:],
            earnedBadgeNames: []
        )
        XCTAssertTrue(badges.contains(where: { $0.name == "Ember" }))
        XCTAssertTrue(badges.contains(where: { $0.name == "Flame" }))
    }

    func test10PrayerCompletionsEarnsPrayerBeginner() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 10,
            currentStreak: 0,
            categoryCounts: [.prayer: 10],
            earnedBadgeNames: []
        )
        XCTAssertTrue(badges.contains(where: { $0.name == "Prayer Beginner" }))
    }

    func test25PrayerCompletionsEarnsPrayerDevotedAndKeepsBeginner() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 25,
            currentStreak: 0,
            categoryCounts: [.prayer: 25],
            earnedBadgeNames: []
        )
        XCTAssertTrue(badges.contains(where: { $0.name == "Prayer Beginner" }))
        XCTAssertTrue(badges.contains(where: { $0.name == "Prayer Devoted" }))
    }

    func testSameBadgeIsNotAwardedTwice() {
        let badges = BadgeEvaluator.evaluate(
            totalCompleted: 31,
            currentStreak: 7,
            categoryCounts: [:],
            earnedBadgeNames: ["journey_5k", "streak_ember"]
        )
        XCTAssertFalse(badges.contains(where: { $0.id == "journey_5k" }), "Already earned 5K should not appear again")
        XCTAssertFalse(badges.contains(where: { $0.id == "streak_ember" }), "Already earned Ember should not appear again")
    }

    func testEvaluateAndAwardReturnsOnlyNewBadges() {
        // First evaluation: earn 5K
        let firstBadges = BadgeEvaluator.evaluate(
            totalCompleted: 31,
            currentStreak: 0,
            categoryCounts: [:],
            earnedBadgeNames: []
        )
        XCTAssertTrue(firstBadges.contains(where: { $0.name == "5K" }))

        // Second evaluation with 5K already earned: should not include 5K
        let earnedNames = Set(firstBadges.map(\.id))
        let secondBadges = BadgeEvaluator.evaluate(
            totalCompleted: 31,
            currentStreak: 0,
            categoryCounts: [:],
            earnedBadgeNames: earnedNames
        )
        XCTAssertFalse(secondBadges.contains(where: { $0.name == "5K" }), "5K should not be returned again")
    }
}
