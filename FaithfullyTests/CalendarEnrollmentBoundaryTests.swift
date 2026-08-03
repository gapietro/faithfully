import XCTest
import SwiftData
@testable import Faithfully

/// Split out of CalendarViewModelTests: how the grid presents days the user was
/// not enrolled for is a subject in its own right, and the combined class had
/// outgrown the length the linter enforces.
final class CalendarEnrollmentBoundaryTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var badgeService: BadgeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        badgeService = BadgeService(modelContext: context)
    }

    private func makeService(today: Date, enrolledOn: Date) throws -> ChallengeService {
        try ChallengeService(
            modelContext: context,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: enrolledOn,
            dateProvider: { today }
        )
    }

    // MARK: - Enrollment boundary (CLEAN-002)

    func testDaysBeforeEnrollmentAreMarkedPreEnrollmentNotMissed() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today, enrolledOn: Date.from(year: 2026, month: 4, day: 10))
        let vm = CalendarViewModel(challengeService: service, today: today)

        func status(day: Int) -> CalendarDayStatus? {
            vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == day }?.status
        }

        XCTAssertEqual(status(day: 9), .preEnrollment, "The day before enrollment is not a miss")
        XCTAssertEqual(status(day: 1), .preEnrollment)
        XCTAssertEqual(status(day: 10), .missed,
                       "The enrollment day is a real day the user was here for — a genuine miss "
                       + "once its grace window closes, not pre-enrollment")
        XCTAssertEqual(status(day: 13), .missedRecoverable,
                       "A post-enrollment day inside the grace window stays recoverable")
        XCTAssertEqual(status(day: 15), .today)

        let preEnrollmentDays = vm.calendarDays.filter { $0.status == .preEnrollment }
        XCTAssertEqual(preEnrollmentDays.count, 9, "April 1–9 precede enrollment on the 10th")
    }

    func testCompleteGracePeriodRefusesPreEnrollmentDays() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today, enrolledOn: Date.from(year: 2026, month: 4, day: 14))
        let vm = CalendarViewModel(challengeService: service, today: today)

        // April 13 is inside the grace window but precedes enrollment.
        let day13 = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 13
        })
        XCTAssertEqual(day13.status, .preEnrollment)

        vm.completeGracePeriod(day13, journal: "should not persist")

        let after = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 13 }
        XCTAssertEqual(after?.status, .preEnrollment, "The day must not flip to completed")
        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletedChallenge>()).count, 0,
                       "No completion may be written for a pre-enrollment day")
    }

    func testEnrollingTodayLeavesNoRecoverableHistory() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today, enrolledOn: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        XCTAssertTrue(
            vm.calendarDays.filter { Calendar.current.component(.day, from: $0.date) < 15 }
                .allSatisfy { $0.status == .preEnrollment },
            "A user who enrolled today has no earlier days to recover"
        )
    }
}
