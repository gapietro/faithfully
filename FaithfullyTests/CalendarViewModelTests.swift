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

    private func makeService(today: Date) -> ChallengeService {
        ChallengeService(modelContext: context, challenges: challenges, badgeService: badgeService, dateProvider: { today })
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
