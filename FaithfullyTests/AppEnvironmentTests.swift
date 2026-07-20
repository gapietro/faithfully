import XCTest
import SwiftData
@testable import Faithfully

final class AppEnvironmentTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
    }

    private func makeEnvironment(
        today: Date = .now,
        loader: (() throws -> [DailyChallenge])? = nil
    ) -> AppEnvironment {
        AppEnvironment(
            modelContext: context,
            loadChallenges: loader ?? { self.challenges },
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

    // MARK: - Year rotation in the live app path (#4)

    func testLiveServicePathAppliesYearRotationFromProfileStartDate() throws {
        // A profile that started two years ago must see rotated pairings today.
        let startDate = Date.from(year: 2024, month: 1, day: 1)
        context.insert(UserProfile(startDate: startDate))
        try context.save()

        let today = Date.from(year: 2026, month: 6, day: 15)
        let env = makeEnvironment(today: today)
        let services = try XCTUnwrap(env.services)
        let scheduler = try XCTUnwrap(ChallengeScheduler(challenges: challenges))

        XCTAssertEqual(services.challengeService.challengeForDate(today).id,
                       scheduler.challengeForDate(today, yearOffset: 2).id,
                       "Live path must derive the year offset from the profile start date")
        XCTAssertNotEqual(services.challengeService.challengeForDate(today).id,
                          scheduler.challengeForDate(today, yearOffset: 0).id)
    }
}
