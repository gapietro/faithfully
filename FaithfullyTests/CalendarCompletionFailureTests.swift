import XCTest
import SwiftData
@testable import Faithfully

/// GRADE-001: the calendar was the one write path that dropped its failure on
/// the floor — an empty `catch` whose comment named only the two guard-rail
/// refusals, and a caller that dismissed the panel either way. A persistence
/// failure therefore closed the detail with no message and no completion, and
/// the user's streak silently did not move.
///
/// Shares `InjectablePersistence` with `PersistenceFailureTests`; kept in its
/// own file because that class is already at the type-length limit.
final class CalendarCompletionFailureTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var persistence: InjectablePersistence!
    var badgeService: BadgeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        persistence = InjectablePersistence(context: context)
        badgeService = BadgeService(persistence: persistence)
    }

    private func makeViewModel(today: Date) throws -> (CalendarViewModel, ChallengeService) {
        let service = try ChallengeService(
            persistence: persistence,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: TestHelpers.longEnrolledDate,
            dateProvider: { today }
        )
        return (CalendarViewModel(challengeService: service, today: today), service)
    }

    private func day(_ vm: CalendarViewModel, dayOfMonth: Int) throws -> CalendarDay {
        try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == dayOfMonth
        })
    }

    func testFailedGraceCompletionIsReportedToTheCaller() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let (vm, _) = try makeViewModel(today: today)
        let recoverable = try day(vm, dayOfMonth: 13)
        XCTAssertEqual(recoverable.status, .missedRecoverable,
                       "Precondition: two days ago is inside the grace window")

        persistence.failEverySave = true
        let result = vm.completeGracePeriod(recoverable)

        XCTAssertEqual(result, .failed(.couldNotSave),
                       "A completion that could not be written must say so")
    }

    func testFailedGraceCompletionLeavesTheDayCompletable() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let (vm, service) = try makeViewModel(today: today)
        let recoverable = try day(vm, dayOfMonth: 13)

        persistence.failEverySave = true
        _ = vm.completeGracePeriod(recoverable)

        XCTAssertFalse(service.isCompleted(on: recoverable.date),
                       "Nothing was written, so the user must be able to try again")
        XCTAssertEqual(try day(vm, dayOfMonth: 13).status, .missedRecoverable,
                       "The grid must not show a completion that never happened")
    }

    /// The guard-rail errors keep their existing behaviour: they are refusals
    /// rather than failures, and each carries its own message.
    func testGraceCompletionOutsideTheWindowReportsWhyRatherThanNothing() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let (vm, _) = try makeViewModel(today: today)
        let expired = try day(vm, dayOfMonth: 1)
        XCTAssertEqual(expired.status, .missed, "Precondition: two weeks ago is outside grace")

        XCTAssertEqual(vm.completeGracePeriod(expired), .failed(.gracePeriodExpired))
    }

    func testSuccessfulGraceCompletionStillReportsSuccessAndUpdatesTheGrid() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let (vm, service) = try makeViewModel(today: today)
        let recoverable = try day(vm, dayOfMonth: 13)

        XCTAssertTrue(vm.completeGracePeriod(recoverable).isCompleted)
        XCTAssertTrue(service.isCompleted(on: recoverable.date))
        XCTAssertEqual(try day(vm, dayOfMonth: 13).status, .completed)
    }

    /// The open detail panel is a value-type snapshot, so a successful
    /// completion has to re-bind it or the panel keeps offering "Complete Now"
    /// for a day that is already done.
    func testSuccessfulGraceCompletionRebindsTheOpenDetailPanel() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let (vm, _) = try makeViewModel(today: today)
        let recoverable = try day(vm, dayOfMonth: 13)
        vm.selectDay(recoverable)

        XCTAssertTrue(vm.completeGracePeriod(recoverable).isCompleted)
        XCTAssertEqual(vm.selectedDay?.status, .completed,
                       "The open panel must reflect the completion it just made")
    }
}
