import XCTest
import SwiftData
@testable import Faithfully

final class AppEnvironmentTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var mockNotificationCenter: MockNotificationCenter!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        mockNotificationCenter = MockNotificationCenter()
    }

    private func makeEnvironment(
        today: Date = .now,
        loader: (() throws -> [DailyChallenge])? = nil
    ) -> AppEnvironment {
        AppEnvironment(
            modelContext: context,
            loadChallenges: loader ?? { self.challenges },
            notificationService: NotificationService(center: mockNotificationCenter),
            dateProvider: { today }
        )
    }

    // MARK: - Single service graph (#6)

    func testSuccessfulLoadBuildsSharedServiceGraph() throws {
        let env = makeEnvironment()
        guard case .ready = env.state else {
            XCTFail("Expected ready state, got \(env.state)")
            return
        }
        let services = try XCTUnwrap(env.services)
        XCTAssertEqual(services.challenges.count, challenges.count)
    }

    func testProfileBootstrapHappensOnce() throws {
        _ = makeEnvironment()
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).count, 1)

        // A second environment (simulated relaunch) reuses the same profile
        _ = makeEnvironment()
        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).count, 1)
    }

    func testCompletionOnDailyWalkRefreshesCalendarAndJourney() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let env = makeEnvironment(today: today)
        let services = try XCTUnwrap(env.services)

        XCTAssertEqual(services.journeyViewModel.totalCompleted, 0)
        let dayBefore = services.calendarViewModel.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        }
        XCTAssertNotEqual(dayBefore?.status, .completed)

        services.dailyWalkViewModel.complete(journal: nil)

        XCTAssertTrue(services.dailyWalkViewModel.isCompleted)
        XCTAssertEqual(services.journeyViewModel.totalCompleted, 1,
                       "Journey must reflect a Daily Walk completion without a relaunch")
        let dayAfter = services.calendarViewModel.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        }
        XCTAssertEqual(dayAfter?.status, .completed,
                       "Calendar must reflect a Daily Walk completion without a relaunch")
    }

    func testGracePeriodCompletionOnCalendarRefreshesJourney() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let env = makeEnvironment(today: today)
        let services = try XCTUnwrap(env.services)

        let graceDay = try XCTUnwrap(services.calendarViewModel.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 13
        })
        XCTAssertEqual(graceDay.status, .missedRecoverable)

        services.calendarViewModel.completeGracePeriod(graceDay, journal: nil)

        XCTAssertEqual(services.journeyViewModel.totalCompleted, 1)
    }

    // MARK: - Fail-closed loading (#5)

    func testLoadFailureFailsClosed() {
        let env = makeEnvironment(loader: { throw ChallengeLoader.LoadError.fileNotFound })
        guard case .failed = env.state else {
            XCTFail("Expected failed state, got \(env.state)")
            return
        }
        XCTAssertNil(env.services, "No service graph may exist after a failed load")
    }

    func testEmptyChallengePoolFailsClosed() {
        let env = makeEnvironment(loader: { [] })
        guard case .failed = env.state else {
            XCTFail("Expected failed state for empty pool, got \(env.state)")
            return
        }
        XCTAssertNil(env.services)
    }

    func testRetryAfterFailureRecovers() throws {
        var shouldFail = true
        let env = makeEnvironment(loader: {
            if shouldFail { throw ChallengeLoader.LoadError.fileNotFound }
            return self.challenges
        })
        guard case .failed = env.state else {
            XCTFail("Expected failed state before retry")
            return
        }

        shouldFail = false
        env.retry()

        guard case .ready = env.state else {
            XCTFail("Expected ready state after successful retry")
            return
        }
        XCTAssertNotNil(env.services)
    }

    // MARK: - Day rollover on foreground (PR #15)

    /// Builds an environment whose date provider reads a mutable box, so tests
    /// can cross midnight while the service graph stays in memory.
    private func makeRolloverEnvironment(startingAt start: Date) throws -> (AppServices, (Date) -> Void) {
        var now = start
        let env = AppEnvironment(
            modelContext: context,
            loadChallenges: { self.challenges },
            notificationService: NotificationService(center: mockNotificationCenter),
            dateProvider: { now }
        )
        let services = try XCTUnwrap(env.services)
        return (services, { now = $0 })
    }

    func testForegroundRefreshRollsDailyWalkToNewDay() throws {
        let day15 = Date.from(year: 2026, month: 6, day: 15)
        let (services, setNow) = try makeRolloverEnvironment(startingAt: day15)

        services.dailyWalkViewModel.complete(journal: nil)
        XCTAssertTrue(services.dailyWalkViewModel.isCompleted)
        let day15Challenge = services.dailyWalkViewModel.todayChallenge

        let day16 = Date.from(year: 2026, month: 6, day: 16)
        setNow(day16)
        services.refreshForCurrentDate()

        XCTAssertEqual(services.dailyWalkViewModel.todayChallenge.id,
                       services.challengeService.challengeForDate(day16).id,
                       "Daily Walk must show the new day's challenge after foregrounding")
        XCTAssertEqual(services.dailyWalkViewModel.yesterdayChallenge.id, day15Challenge.id)
        XCTAssertFalse(services.dailyWalkViewModel.isCompleted,
                       "The new day must not inherit yesterday's completed state")
    }

    func testForegroundRefreshOnSameDayKeepsDailyWalkState() throws {
        let day15 = Date.from(year: 2026, month: 6, day: 15)
        let (services, setNow) = try makeRolloverEnvironment(startingAt: day15)

        services.dailyWalkViewModel.complete(journal: nil)
        setNow(day15.addingTimeInterval(3600))
        services.refreshForCurrentDate()

        XCTAssertTrue(services.dailyWalkViewModel.isCompleted,
                      "A same-day foreground must not reset completed state")
    }

    func testForegroundRefreshMovesCalendarTodayBoundaryAndGraceWindows() throws {
        let day15 = Date.from(year: 2026, month: 6, day: 15)
        let (services, setNow) = try makeRolloverEnvironment(startingAt: day15)

        func status(day: Int) -> CalendarDayStatus? {
            services.calendarViewModel.calendarDays.first {
                Calendar.current.component(.day, from: $0.date) == day
            }?.status
        }

        XCTAssertEqual(status(day: 16), .future)
        XCTAssertEqual(status(day: 12), .missedRecoverable,
                       "June 12 is inside the 3-day grace window on the 15th")

        setNow(Date.from(year: 2026, month: 6, day: 16))
        services.refreshForCurrentDate()

        XCTAssertEqual(status(day: 16), .today,
                       "The real current day must no longer be labeled future")
        XCTAssertEqual(status(day: 17), .future)
        XCTAssertEqual(status(day: 12), .missed,
                       "The grace window for June 12 expires when the day rolls to the 16th")
    }

    func testForegroundRefreshAcrossMonthBoundaryFollowsToNewMonth() throws {
        let june30 = Date.from(year: 2026, month: 6, day: 30)
        let (services, setNow) = try makeRolloverEnvironment(startingAt: june30)

        setNow(Date.from(year: 2026, month: 7, day: 1))
        services.refreshForCurrentDate()

        let components = Calendar.current.dateComponents(
            [.year, .month], from: services.calendarViewModel.currentMonth
        )
        XCTAssertEqual(components.month, 7,
                       "A user viewing the current month follows the rollover into July")
        XCTAssertEqual(services.calendarViewModel.calendarDays.count, 31)
    }

    func testForegroundRefreshPreservesBrowsedMonth() throws {
        let day15 = Date.from(year: 2026, month: 6, day: 15)
        let (services, setNow) = try makeRolloverEnvironment(startingAt: day15)

        services.calendarViewModel.previousMonth()
        setNow(Date.from(year: 2026, month: 6, day: 16))
        services.refreshForCurrentDate()

        XCTAssertEqual(Calendar.current.component(.month, from: services.calendarViewModel.currentMonth), 5,
                       "A day rollover must not yank the user away from a month they were browsing")
    }

    // MARK: - Global rotation in the live app path (CLEAN-001)

    func testLiveServicePathUsesGlobalRotationRegardlessOfProfileStartDate() throws {
        // A profile enrolled two years ago must see the same pairing as a brand
        // new profile: the offset comes from the global epoch, not tenure.
        let startDate = Date.from(year: 2024, month: 1, day: 1)
        context.insert(UserProfile(startDate: startDate))
        try context.save()

        let today = Date.from(year: 2026, month: 6, day: 15)
        let env = makeEnvironment(today: today)
        let services = try XCTUnwrap(env.services)
        let scheduler = try XCTUnwrap(ChallengeScheduler(challenges: challenges))
        let globalOffset = ChallengeScheduler.globalYearOffset(for: today)

        XCTAssertEqual(services.challengeService.challengeForDate(today).id,
                       scheduler.challengeForDate(today, yearOffset: globalOffset).id,
                       "Live path must use the global epoch offset, not the profile start date")
        XCTAssertNotEqual(globalOffset, 2,
                          "Guard: tenure offset (2 years) must differ from the global offset here")
    }
}
