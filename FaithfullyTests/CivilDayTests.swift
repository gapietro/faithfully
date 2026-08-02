import XCTest
import SwiftData
@testable import Faithfully

/// The behaviour CLEAN-005 exists for: a completed day must not move when the
/// reader's calendar does.
final class CivilDayTests: XCTestCase {

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: iso)!
    }

    // MARK: - Key derivation

    func testKeyIsTheCivilDateNotTheInstant() {
        // 2026-06-15 23:30 in Auckland is still 2026-06-15 there, and already
        // 2026-06-15 11:30 in New York — different instants, one civil date each.
        let auckland = calendar("Pacific/Auckland")
        let instant = date("2026-06-15T23:30:00+12:00")
        XCTAssertEqual(CivilDay.key(for: instant, calendar: auckland), 20_260_615)
    }

    func testKeySortsChronologically() {
        let keys = [
            CivilDay.key(for: Date.from(year: 2026, month: 1, day: 9)),
            CivilDay.key(for: Date.from(year: 2026, month: 1, day: 10)),
            CivilDay.key(for: Date.from(year: 2026, month: 2, day: 1)),
            CivilDay.key(for: Date.from(year: 2027, month: 1, day: 1))
        ]
        XCTAssertEqual(keys, keys.sorted(), "Integer order must be chronological order")
    }

    func testKeyRoundTripsThroughDate() throws {
        // Includes Feb 29 2028 — a leap day, which a naive yyyyMMdd round trip
        // through a non-leap year would silently move to March 1.
        for key in [20_260_101, 20_260_615, 20_261_231, 20_280_229] {
            let date = try XCTUnwrap(CivilDay.date(for: key), "\(key) must be a real date")
            XCTAssertEqual(CivilDay.key(for: date), key)
        }
    }

    // MARK: - DST

    func testDayArithmeticCrossesSpringForwardWithoutSkippingADay() throws {
        // US DST 2026: clocks jump forward on March 8. That day is 23 hours long,
        // so subtracting 86,400 seconds from March 9 lands on March 8 at 01:00 —
        // still March 8, but arithmetic on seconds is how a day gets skipped.
        let newYork = calendar("America/New_York")
        let march9 = 20_260_309

        var walked: [Int] = [march9]
        var cursor = march9
        for _ in 0..<3 {
            cursor = try XCTUnwrap(CivilDay.key(cursor, offsetByDays: -1, calendar: newYork))
            walked.append(cursor)
        }
        XCTAssertEqual(walked, [20_260_309, 20_260_308, 20_260_307, 20_260_306],
                       "Every calendar day across the transition must be visited exactly once")
    }

    func testDayArithmeticCrossesFallBackWithoutRepeatingADay() throws {
        // US DST 2026 ends November 1; that day is 25 hours long.
        let newYork = calendar("America/New_York")
        var walked: [Int] = [20_261_102]
        var cursor = 20_261_102
        for _ in 0..<2 {
            cursor = try XCTUnwrap(CivilDay.key(cursor, offsetByDays: -1, calendar: newYork))
            walked.append(cursor)
        }
        XCTAssertEqual(walked, [20_261_102, 20_261_101, 20_261_031])
    }

    func testDaysBetweenSpansADstTransition() {
        let newYork = calendar("America/New_York")
        XCTAssertEqual(CivilDay.daysBetween(20_260_306, 20_260_310, calendar: newYork), 4)
        XCTAssertEqual(CivilDay.daysBetween(20_261_030, 20_261_103, calendar: newYork), 4)
    }

    // MARK: - The regression: a completion must not move

    func testAStoredCompletionKeepsItsDayAfterCrossingTheDateLine() throws {
        // Complete just after midnight in Auckland, then fly to Honolulu — 22
        // hours behind, so the same instant is the *previous* calendar day there.
        // Under the old model the stored instant was reinterpreted on read and
        // the completion moved a day.
        let auckland = calendar("Pacific/Auckland")
        let honolulu = calendar("Pacific/Honolulu")
        let completionInstant = date("2026-06-15T00:30:00+12:00")

        let recordedKey = CivilDay.key(for: completionInstant, calendar: auckland)
        XCTAssertEqual(recordedKey, 20_260_615)

        // What the old code did — re-derive from the instant under the new calendar.
        let reinterpreted = CivilDay.key(for: completionInstant, calendar: honolulu)
        XCTAssertNotEqual(reinterpreted, recordedKey,
                          "Precondition: this instant genuinely resolves to a different day in Honolulu")

        // What the new model does: the key was frozen at write time and is read
        // back verbatim, so the day the user completed stays the day they completed.
        let stored = CompletedChallenge(
            challengeId: "c1", challengeCategory: "prayer",
            completedDate: completionInstant, scheduledDate: completionInstant,
            dayKey: recordedKey
        )
        XCTAssertEqual(stored.dayKey, 20_260_615,
                       "A completed day must not move because the user did")
    }

    func testStreakSurvivesATimeZoneChange() {
        // Seven consecutive days, then the device moves 22 hours west.
        let keys = (0..<7).compactMap { CivilDay.key(20_260_615, offsetByDays: -$0) }
        XCTAssertEqual(keys.count, 7)

        let todayInOriginalZone = Date.from(year: 2026, month: 6, day: 15)
        XCTAssertEqual(
            StreakCalculator.calculateStreak(completedDayKeys: keys, today: todayInOriginalZone),
            7
        )

        // The keys are unchanged by the move; only "today" is re-evaluated, which
        // is correct — the user really is on a new local day.
        let nextLocalDay = Date.from(year: 2026, month: 6, day: 16)
        XCTAssertEqual(
            StreakCalculator.calculateStreak(completedDayKeys: keys, today: nextLocalDay),
            7,
            "Yesterday's streak stands until today's window closes"
        )
    }

    func testStreakBreaksOnAGenuinelyMissedDay() {
        // Guard against the fix over-correcting into "streaks never break".
        let keys = [20_260_615, 20_260_614, 20_260_612, 20_260_611]
        XCTAssertEqual(
            StreakCalculator.calculateStreak(
                completedDayKeys: keys, today: Date.from(year: 2026, month: 6, day: 15)
            ),
            2,
            "June 13 is missing, so the streak is June 14-15"
        )
    }

    // MARK: - Query identity

    func testCompletionLookupMatchesOnCivilDayNotInstantWindow() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = ModelContext(container)
        let challenges = try TestHelpers.loadTestChallenges()
        let persistence = PersistenceCoordinator(context: context)
        let badgeService = BadgeService(persistence: persistence)
        let day = Date.from(year: 2026, month: 6, day: 15)
        let service = try ChallengeService(
            persistence: persistence, challenges: challenges, badgeService: badgeService,
            enrollmentDate: TestHelpers.longEnrolledDate, dateProvider: { day }
        )

        _ = try service.completeChallenge(service.challengeForDate(day), on: day, journal: nil)

        // Any instant on that civil day resolves to the same completion.
        for hourOffset in [-11, -6, 0, 6, 11] {
            let sameDayDifferentHour = day.addingTimeInterval(Double(hourOffset) * 3600)
            XCTAssertTrue(
                service.isCompleted(on: sameDayDifferentHour),
                "Hour \(hourOffset) of the same civil day must find the completion"
            )
        }
        XCTAssertFalse(service.isCompleted(on: day.addingDays(1)))
        XCTAssertFalse(service.isCompleted(on: day.addingDays(-1)))
    }

    func testMonthFetchIncludesTheFirstAndLastDayOfTheMonth() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = ModelContext(container)
        let challenges = try TestHelpers.loadTestChallenges()
        let persistence = PersistenceCoordinator(context: context)
        let service = try ChallengeService(
            persistence: persistence, challenges: challenges,
            badgeService: BadgeService(persistence: persistence),
            enrollmentDate: TestHelpers.longEnrolledDate,
            dateProvider: { Date.from(year: 2026, month: 6, day: 30) }
        )

        for day in [1, 15, 30] {
            let date = Date.from(year: 2026, month: 6, day: day)
            let challenge = service.challengeForDate(date)
            context.insert(CompletedChallenge(
                challengeId: challenge.id, challengeCategory: challenge.category.rawValue,
                completedDate: date, scheduledDate: date.startOfDay
            ))
        }
        try context.save()

        let fetched = service.fetchCompletions(
            for: Date.from(year: 2026, month: 6, day: 1)...Date.from(year: 2026, month: 6, day: 30)
        )
        XCTAssertEqual(fetched.count, 3,
                       "An inclusive civil-day range must contain both endpoints")
    }
}
