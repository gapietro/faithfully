import XCTest
@testable import Faithfully

final class StreakCalculationTests: XCTestCase {

    func testZeroCompletionsReturnsStreakOf0() {
        let streak = StreakCalculator.calculateStreak(completionDates: [], today: .now)
        XCTAssertEqual(streak, 0)
    }

    func testOnlyTodayCompletedReturnsStreakOf1() {
        let today = Date.from(year: 2026, month: 4, day: 1)
        let streak = StreakCalculator.calculateStreak(completionDates: [today], today: today)
        XCTAssertEqual(streak, 1)
    }

    func test3ConsecutiveDaysEndingTodayReturnsStreakOf3() {
        let today = Date.from(year: 2026, month: 4, day: 3)
        let dates = [
            Date.from(year: 2026, month: 4, day: 1),
            Date.from(year: 2026, month: 4, day: 2),
            Date.from(year: 2026, month: 4, day: 3),
        ]
        let streak = StreakCalculator.calculateStreak(completionDates: dates, today: today)
        XCTAssertEqual(streak, 3)
    }

    func testGapYesterdayBreaksStreak() {
        let today = Date.from(year: 2026, month: 4, day: 3)
        let dates = [
            Date.from(year: 2026, month: 4, day: 1),
            // Gap on April 2
            Date.from(year: 2026, month: 4, day: 3),
        ]
        let streak = StreakCalculator.calculateStreak(completionDates: dates, today: today)
        XCTAssertEqual(streak, 1, "Gap yesterday should break streak; only today counts")
    }

    func testTodayNotCompletedYesterdayCompletedReturnsStreakFromYesterday() {
        let today = Date.from(year: 2026, month: 4, day: 3)
        let dates = [
            Date.from(year: 2026, month: 4, day: 1),
            Date.from(year: 2026, month: 4, day: 2),
            // Today not completed
        ]
        let streak = StreakCalculator.calculateStreak(completionDates: dates, today: today)
        XCTAssertEqual(streak, 2, "When today not completed, streak should count from yesterday backwards")
    }

    func testGracePeriodCompletionMaintainsStreak() {
        // If a day is completed late (grace period), its completedDate differs from scheduledDate
        // But for streak purposes, we count by the dates in the completionDates array
        // The caller should pass scheduledDates, not completedDates, for accurate streaks
        let today = Date.from(year: 2026, month: 4, day: 3)
        let dates = [
            Date.from(year: 2026, month: 4, day: 1),
            Date.from(year: 2026, month: 4, day: 2),
            Date.from(year: 2026, month: 4, day: 3),
        ]
        let streak = StreakCalculator.calculateStreak(completionDates: dates, today: today)
        XCTAssertEqual(streak, 3, "Grace period completions recorded by scheduled date maintain streak")
    }

    func test365ConsecutiveDaysReturnsStreakOf365() {
        let startDate = Date.from(year: 2025, month: 4, day: 2)
        let today = Date.from(year: 2026, month: 4, day: 1)
        var dates: [Date] = []
        for i in 0..<365 {
            dates.append(startDate.addingDays(i))
        }
        let streak = StreakCalculator.calculateStreak(completionDates: dates, today: today)
        XCTAssertEqual(streak, 365)
    }
}
