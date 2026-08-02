import XCTest
import SwiftData
@testable import Faithfully

/// Split out of ChallengeServiceTests: enrollment eligibility is a subject in
/// its own right, and the combined class had outgrown the length the linter
/// enforces.
final class ChallengeServiceEnrollmentTests: XCTestCase {

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
    // MARK: - Enrollment boundary (CLEAN-002)

    private func makeEnrolledService(enrolledOn: Date, today: Date) throws -> ChallengeService {
        try ChallengeService(
            modelContext: context,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: enrolledOn,
            dateProvider: { today }
        )
    }

    func testCompletionIsRejectedTheDayBeforeEnrollment() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)
        let dayBefore = enrolled.addingDays(-1)

        XCTAssertThrowsError(
            try service.completeChallenge(service.challengeForDate(dayBefore), on: dayBefore, journal: nil)
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .beforeEnrollment)
        }
        XCTAssertFalse(service.isCompleted(on: dayBefore))
        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletedChallenge>()).count, 0)
    }

    func testCompletionIsAcceptedOnTheEnrollmentDayItself() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)

        XCTAssertNoThrow(
            try service.completeChallenge(service.challengeForDate(enrolled), on: enrolled, journal: nil)
        )
        XCTAssertTrue(service.isCompleted(on: enrolled))
    }

    func testCompletionIsAcceptedTheDayAfterEnrollment() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let dayAfter = enrolled.addingDays(1)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: dayAfter)

        XCTAssertNoThrow(
            try service.completeChallenge(service.challengeForDate(dayAfter), on: dayAfter, journal: nil)
        )
        XCTAssertTrue(service.isCompleted(on: dayAfter))
    }

    /// Enrollment is checked before the grace window, so no combination of the
    /// two can be used to backfill history that predates the account.
    func testGraceWindowCannotBackfillPreEnrollmentDays() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let today = Date.from(year: 2026, month: 6, day: 16)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: today)

        // Days 13 and 14 sit inside the 3-day grace window from the 16th,
        // but both precede enrollment on the 15th.
        for offset in [-2, -1] {
            let date = enrolled.addingDays(offset)
            XCTAssertTrue(GracePeriod.canComplete(challengeDate: date, today: today),
                          "Precondition: \(date) must be inside the grace window")
            XCTAssertThrowsError(
                try service.completeChallenge(service.challengeForDate(date), on: date, journal: nil)
            ) { error in
                XCTAssertEqual(error as? ChallengeServiceError, .beforeEnrollment,
                               "Grace must not override enrollment for \(date)")
            }
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletedChallenge>()).count, 0)
    }

    func testEnrollmentBoundaryHoldsAcrossMonthRollover() throws {
        let enrolled = Date.from(year: 2026, month: 7, day: 1)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)
        let lastDayOfPreviousMonth = Date.from(year: 2026, month: 6, day: 30)

        XCTAssertThrowsError(
            try service.completeChallenge(
                service.challengeForDate(lastDayOfPreviousMonth), on: lastDayOfPreviousMonth, journal: nil
            )
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .beforeEnrollment)
        }
    }

    func testEnrollmentBoundaryHoldsAcrossYearRollover() throws {
        let enrolled = Date.from(year: 2027, month: 1, day: 1)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)
        let newYearsEve = Date.from(year: 2026, month: 12, day: 31)

        XCTAssertThrowsError(
            try service.completeChallenge(service.challengeForDate(newYearsEve), on: newYearsEve, journal: nil)
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .beforeEnrollment)
        }
    }

    /// The boundary is a calendar day, not an instant: enrolling at 9pm must not
    /// lock the user out of the day they actually joined on.
    func testEnrollmentBoundaryComparesWholeDaysNotInstants() throws {
        // Date.from anchors at noon, so these offsets are 9pm and 8am on June 15.
        let noon = Date.from(year: 2026, month: 6, day: 15)
        let enrolledLateInTheDay = noon.addingTimeInterval(9 * 3600)
        let morningOfSameDay = noon.addingTimeInterval(-4 * 3600)
        XCTAssertTrue(
            Calendar.current.isDate(enrolledLateInTheDay, inSameDayAs: morningOfSameDay),
            "Precondition: both instants must fall on the same civil day"
        )
        let service = try makeEnrolledService(
            enrolledOn: enrolledLateInTheDay, today: enrolledLateInTheDay
        )

        XCTAssertNoThrow(
            try service.completeChallenge(
                service.challengeForDate(morningOfSameDay), on: morningOfSameDay, journal: nil
            )
        )
    }

    func testEnrollmentDateIsExposedForCalendarRendering() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)
        XCTAssertEqual(service.enrollmentDate, enrolled)
    }
}
