import XCTest
import SwiftData
@testable import Faithfully

final class CalendarViewModelTests: XCTestCase {

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

    /// Enrollment defaults to well before any date these tests use, so they keep
    /// exercising grace/missed/future semantics rather than the enrollment
    /// boundary. Tests that are about the boundary pass `enrolledOn` explicitly.
    private func makeService(today: Date, enrolledOn: Date = Date.from(year: 2020, month: 1, day: 1)) -> ChallengeService {
        try! ChallengeService(
            modelContext: context,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: enrolledOn,
            dateProvider: { today }
        )
    }

    func testCalendarDaysContainsCorrectNumberOfDaysForCurrentMonth() {
        let april = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: april)
        let vm = CalendarViewModel(challengeService: service, today: april)
        XCTAssertEqual(vm.calendarDays.count, 30)
    }

    func testCompletedDaysShowCompletedStatus() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let april10 = Date.from(year: 2026, month: 4, day: 10)
        let challenge = service.challengeForDate(april10)
        let completion = CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: april10,
            scheduledDate: april10
        )
        context.insert(completion)
        try context.save()

        let vm = CalendarViewModel(challengeService: service, today: today)
        let day10 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 10 }
        XCTAssertEqual(day10?.status, .completed)
    }

    func testTodayNotCompletedShowsTodayStatus() {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        let day15 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 15 }
        XCTAssertEqual(day15?.status, .today,
                       "An incomplete today must be distinguishable, not styled as a recoverable miss")
    }

    func testTodayCompletedShowsCompletedNotToday() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        let vm = CalendarViewModel(challengeService: service, today: today)
        let day15 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 15 }
        XCTAssertEqual(day15?.status, .completed, "Completed takes precedence over .today")
    }

    func testCompletingTodayViaGracePathMovesTodayToCompleted() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        let day15 = try XCTUnwrap(vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 15 })
        XCTAssertEqual(day15.status, .today)

        vm.completeGracePeriod(day15, journal: nil)

        let updated = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 15 }
        XCTAssertEqual(updated?.status, .completed,
                       "Today must remain completable from the calendar and update without relaunch")
    }

    func testMissedDaysWithinGracePeriodShowMissedRecoverable() {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        let day13 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 13 }
        XCTAssertEqual(day13?.status, .missedRecoverable)
    }

    func testMissedDaysOutsideGracePeriodShowMissed() {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        let day5 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 5 }
        XCTAssertEqual(day5?.status, .missed)
    }

    func testFutureDaysShowFuture() {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        let day25 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 25 }
        XCTAssertEqual(day25?.status, .future)
    }

    func testNextMonthAdvancesByOneMonth() {
        let april = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: april)
        let vm = CalendarViewModel(challengeService: service, today: april)
        let initialMonth = Calendar.current.component(.month, from: vm.currentMonth)

        vm.nextMonth()
        let newMonth = Calendar.current.component(.month, from: vm.currentMonth)
        XCTAssertEqual(newMonth, initialMonth + 1)
    }

    func testPreviousMonthGoesBackOneMonth() {
        let april = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: april)
        let vm = CalendarViewModel(challengeService: service, today: april)
        let initialMonth = Calendar.current.component(.month, from: vm.currentMonth)

        vm.previousMonth()
        let newMonth = Calendar.current.component(.month, from: vm.currentMonth)
        XCTAssertEqual(newMonth, initialMonth - 1)
    }

    func testSelectDaySetsSelectedDay() {
        let april = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: april)
        let vm = CalendarViewModel(challengeService: service, today: april)

        XCTAssertNil(vm.selectedDay)
        let day = vm.calendarDays[5]
        vm.selectDay(day)
        XCTAssertEqual(vm.selectedDay, day)
    }

    func testLeapYearFebruaryHas29Days() {
        let leapFeb = Date.from(year: 2028, month: 2, day: 10)
        let service = makeService(today: leapFeb)
        let vm = CalendarViewModel(challengeService: service, today: leapFeb)
        XCTAssertEqual(vm.calendarDays.count, 29)
    }

    func testNonLeapYearFebruaryHas28Days() {
        let feb = Date.from(year: 2026, month: 2, day: 10)
        let service = makeService(today: feb)
        let vm = CalendarViewModel(challengeService: service, today: feb)
        XCTAssertEqual(vm.calendarDays.count, 28)
    }

    func testNextMonthCrossesYearBoundary() {
        let december = Date.from(year: 2026, month: 12, day: 15)
        let service = makeService(today: december)
        let vm = CalendarViewModel(challengeService: service, today: december)

        vm.nextMonth()
        let components = Calendar.current.dateComponents([.year, .month], from: vm.currentMonth)
        XCTAssertEqual(components.year, 2027)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(vm.calendarDays.count, 31)
    }

    func testPreviousMonthCrossesYearBoundary() {
        let january = Date.from(year: 2026, month: 1, day: 15)
        let service = makeService(today: january)
        let vm = CalendarViewModel(challengeService: service, today: january)

        vm.previousMonth()
        let components = Calendar.current.dateComponents([.year, .month], from: vm.currentMonth)
        XCTAssertEqual(components.year, 2025)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(vm.calendarDays.count, 31)
    }

    func testCompletionOnLastDayOfMonthIsMarkedCompleted() throws {
        // Regression guard for the month-range fetch: a completion scheduled on the
        // last day of the month must be visible in the grid.
        let today = Date.from(year: 2026, month: 4, day: 30)
        let service = makeService(today: today)
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        let vm = CalendarViewModel(challengeService: service, today: today)
        let day30 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 30 }
        XCTAssertEqual(day30?.status, .completed)
    }

    func testReusedChallengeIdOnlyMarksItsOwnDayCompleted() throws {
        // Two days in the grid can share a challenge ID (scheduler reuse). Completing
        // one must not mark the other. Simulate by inserting a completion whose
        // challengeId matches another grid day's challenge.
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let april10 = Date.from(year: 2026, month: 4, day: 10)
        let april20 = Date.from(year: 2026, month: 4, day: 20)
        // Reuse day 20's challenge ID on day 10's completion record
        let reusedChallenge = service.challengeForDate(april20)
        let completion = CompletedChallenge(
            challengeId: reusedChallenge.id,
            challengeCategory: reusedChallenge.category.rawValue,
            completedDate: april10,
            scheduledDate: april10
        )
        context.insert(completion)
        try context.save()

        let vm = CalendarViewModel(challengeService: service, today: today)
        let day10 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 10 }
        let day20 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 20 }
        XCTAssertEqual(day10?.status, .completed, "The scheduled day itself must show completed")
        XCTAssertEqual(day20?.status, .future, "A later day sharing the challenge ID must not show completed")
    }

    func testRefreshRebindsSelectedDayToRebuiltStatus() {
        // Select a recoverable day, then roll past its grace window: the open
        // detail must re-bind to the rebuilt day so it no longer offers Complete.
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        let day13 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 13 }
        vm.selectDay(day13!)
        XCTAssertEqual(vm.selectedDay?.status, .missedRecoverable)

        vm.refresh(for: Date.from(year: 2026, month: 4, day: 19))
        XCTAssertEqual(vm.selectedDay?.status, .missed,
                       "Stale detail must not still offer Complete after grace expiry")
        XCTAssertEqual(vm.selectedDay.map { Calendar.current.component(.day, from: $0.date) }, 13,
                       "Re-bind keeps the same date selected")
    }

    func testRefreshClearsSelectedDayWhenDateLeavesGrid() {
        // Rolling into a new month (while viewing the current month) rebuilds the
        // grid for the new month; a selection from the old month has no matching
        // day and must be dropped rather than left stale.
        let today = Date.from(year: 2026, month: 4, day: 30)
        let service = makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        let day13 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 13 }
        vm.selectDay(day13!)

        vm.refresh(for: Date.from(year: 2026, month: 5, day: 1))
        XCTAssertNil(vm.selectedDay)
    }

    // MARK: - Enrollment boundary (CLEAN-002)

    func testDaysBeforeEnrollmentAreMarkedPreEnrollmentNotMissed() {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today, enrolledOn: Date.from(year: 2026, month: 4, day: 10))
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
        let service = makeService(today: today, enrolledOn: Date.from(year: 2026, month: 4, day: 14))
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

    func testEnrollingTodayLeavesNoRecoverableHistory() {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today, enrolledOn: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        XCTAssertTrue(
            vm.calendarDays.filter { Calendar.current.component(.day, from: $0.date) < 15 }
                .allSatisfy { $0.status == .preEnrollment },
            "A user who enrolled today has no earlier days to recover"
        )
    }

    func testCompleteGracePeriodCallsChallengeServiceAndUpdatesCalendar() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        guard let gracePeriodDay = vm.calendarDays.first(where: {
            Calendar.current.component(.day, from: $0.date) == 13
        }) else {
            XCTFail("Could not find April 13")
            return
        }

        XCTAssertEqual(gracePeriodDay.status, .missedRecoverable)
        vm.completeGracePeriod(gracePeriodDay, journal: "Made up for it")

        let updatedDay13 = vm.calendarDays.first { Calendar.current.component(.day, from: $0.date) == 13 }
        XCTAssertEqual(updatedDay13?.status, .completed)
    }
}
