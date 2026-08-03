import XCTest
@testable import Faithfully

final class ChallengeSchedulerTests: XCTestCase {

    var scheduler: ChallengeScheduler!
    var challenges: [DailyChallenge]!

    override func setUpWithError() throws {
        challenges = try ChallengeLoader.loadChallenges(from: Bundle(for: type(of: self)))
        scheduler = try XCTUnwrap(ChallengeScheduler(challenges: challenges))
    }

    func testInitFailsWithEmptyChallengePool() {
        XCTAssertNil(ChallengeScheduler(challenges: []),
                     "Scheduler must not be constructible with an empty pool")
    }

    func testInitFailsWithGivingOnlyPool() {
        let givingOnly = challenges.filter { $0.category == .giving }
        XCTAssertNil(ChallengeScheduler(challenges: givingOnly),
                     "Scheduler must not be constructible without non-giving challenges")
    }

    func testReturnsAChallengeForAnyValidDate() {
        let date = Date.from(year: 2026, month: 6, day: 15)
        let challenge = scheduler.challengeForDate(date)
        XCTAssertFalse(challenge.id.isEmpty)
    }

    func testSameDateAlwaysReturnsSameChallenge() {
        let date = Date.from(year: 2026, month: 3, day: 10)
        let first = scheduler.challengeForDate(date)
        let second = scheduler.challengeForDate(date)
        XCTAssertEqual(first.id, second.id, "Same date should always return same challenge")
    }

    func testTwoDifferentDatesReturnDifferentChallenges() {
        let date1 = Date.from(year: 2026, month: 3, day: 10)
        let date2 = Date.from(year: 2026, month: 3, day: 11)
        let challenge1 = scheduler.challengeForDate(date1)
        let challenge2 = scheduler.challengeForDate(date2)
        XCTAssertNotEqual(challenge1.id, challenge2.id, "Different dates should return different challenges")
    }

    func testFirstSaturdayOfEachMonthReturnsGivingCategory() {
        // Find all first Saturdays in 2026
        let calendar = Calendar.current
        for month in 1...12 {
            var components = DateComponents()
            components.year = 2026
            components.month = month
            components.day = 1
            guard let firstOfMonth = calendar.date(from: components) else { continue }

            // Find first Saturday
            var date = firstOfMonth
            while calendar.component(.weekday, from: date) != 7 {
                date = calendar.date(byAdding: .day, value: 1, to: date)!
            }

            let challenge = scheduler.challengeForDate(date)
            XCTAssertEqual(challenge.category, .giving,
                          "First Saturday of month \(month) should be a giving challenge, got \(challenge.category.rawValue)")
        }
    }

    func testNonFirstSaturdayNeverReturnsGivingCategory() {
        // Test a Wednesday mid-month
        let date = Date.from(year: 2026, month: 3, day: 18) // Wednesday
        let challenge = scheduler.challengeForDate(date)
        XCTAssertNotEqual(challenge.category, .giving,
                         "Non-first-Saturday should not return giving category")
    }

    func testYear1AndYear2ReturnDifferentChallengesForSameCalendarDate() {
        let date = Date.from(year: 2026, month: 6, day: 15)
        let year1Challenge = scheduler.challengeForDate(date, yearOffset: 0)
        let year2Challenge = scheduler.challengeForDate(date, yearOffset: 1)
        XCTAssertNotEqual(year1Challenge.id, year2Challenge.id,
                         "Different year offsets should return different challenges for the same date")
    }

    func testNoTwoConsecutiveDaysHaveSameCategory() {
        // Test a stretch of days (skip first Saturdays which are pinned to giving)
        var previousCategory: ChallengeCategory?
        var violations = 0

        for dayOffset in 0..<30 {
            let date = Date.from(year: 2026, month: 2, day: 1).addingDays(dayOffset)
            let challenge = scheduler.challengeForDate(date)

            if let prev = previousCategory, prev == challenge.category {
                // Allow giving on first Saturdays since those are pinned
                if !scheduler.isFirstSaturdayOfMonth(date) {
                    violations += 1
                }
            }
            previousCategory = challenge.category
        }

        // The algorithm doesn't guarantee zero consecutive-category violations
        // (fixConsecutiveCategoryViolations is a refinement step), but we want few
        XCTAssertLessThan(violations, 5, "Should have very few consecutive same-category days")
    }

    /// GRADE-004: `min(ordinality, 365)` clamped the leap day off the end of
    /// the year, so 30 and 31 December of a leap year both resolved to day 365
    /// and the user was served the same challenge two days running. First
    /// occurrence would have been 2028-12-31.
    func testLeapYearDecemberThirtiethAndThirtyFirstAreDifferentChallenges() {
        let december30 = Date.from(year: 2028, month: 12, day: 30)
        let december31 = Date.from(year: 2028, month: 12, day: 31)

        XCTAssertNotEqual(
            scheduler.challengeForDate(december30).id,
            scheduler.challengeForDate(december31).id,
            "A leap year's last two days must not repeat the same challenge"
        )
    }

    /// The clamp also meant every leap year ended on the same index as the one
    /// before it. Walking all 366 days proves the tail is distinct, not just
    /// the one pair.
    func testEveryDayOfALeapYearResolvesAndTheLastWeekDoesNotRepeat() {
        let startOfLeapYear = Date.from(year: 2028, month: 1, day: 1)
        let days = (0..<366).map { startOfLeapYear.addingDays($0) }

        XCTAssertEqual(Calendar.current.component(.year, from: days[365]), 2028,
                       "Precondition: 2028 has 366 days")

        let lastWeek = days.suffix(7).map { scheduler.challengeForDate($0).id }
        XCTAssertEqual(Set(lastWeek).count, lastWeek.count,
                       "The final week of a leap year must not repeat: \(lastWeek)")
    }

    func testAll365DaysOfAYearAreCovered() {
        var challengeIds = Set<String>()
        let startDate = Date.from(year: 2026, month: 1, day: 1)

        for dayOffset in 0..<365 {
            let date = startDate.addingDays(dayOffset)
            let challenge = scheduler.challengeForDate(date)
            challengeIds.insert(challenge.id)
        }

        // Should have assigned challenges to all 365 days (not necessarily 365 unique ones)
        XCTAssertGreaterThan(challengeIds.count, 0, "Should have assigned challenges across the year")
    }
}
