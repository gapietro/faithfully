import XCTest
@testable import Faithfully

final class GracePeriodTests: XCTestCase {

    let today = Date.from(year: 2026, month: 4, day: 4)

    func testTodaysChallengeIsCompletable() {
        XCTAssertTrue(GracePeriod.canComplete(challengeDate: today, today: today))
    }

    func testYesterdaysChallengeIsCompletable() {
        let yesterday = today.addingDays(-1)
        XCTAssertTrue(GracePeriod.canComplete(challengeDate: yesterday, today: today))
    }

    func test3DaysAgoChallengeIsCompletable() {
        let threeDaysAgo = today.addingDays(-3)
        XCTAssertTrue(GracePeriod.canComplete(challengeDate: threeDaysAgo, today: today))
    }

    func test4DaysAgoChallengeIsNotCompletable() {
        let fourDaysAgo = today.addingDays(-4)
        XCTAssertFalse(GracePeriod.canComplete(challengeDate: fourDaysAgo, today: today))
    }

    func testFutureChallengeIsNotCompletable() {
        let tomorrow = today.addingDays(1)
        XCTAssertFalse(GracePeriod.canComplete(challengeDate: tomorrow, today: today))
    }

    func testGracePeriodCompletionRecordsCorrectDates() {
        let challengeDate = today.addingDays(-2)
        XCTAssertTrue(GracePeriod.isGracePeriodCompletion(challengeDate: challengeDate, completionDate: today),
                      "Completing a past challenge today should be a grace period completion")
    }

    func testSameDayCompletionIsNotGracePeriod() {
        XCTAssertFalse(GracePeriod.isGracePeriodCompletion(challengeDate: today, completionDate: today),
                      "Completing today's challenge today should not be a grace period completion")
    }
}
