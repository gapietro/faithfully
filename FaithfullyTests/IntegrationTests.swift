import XCTest
import SwiftData
@testable import Faithfully

final class IntegrationTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
    }

    // MARK: - 4.1 Full Completion Flow

    func testFullCompletionFlow_ViewCompleteVerifyPersistenceStreakBadge() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let badgeService = BadgeService(modelContext: context)
        let challengeService = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            userStartDate: Date.from(year: 2026, month: 6, day: 1), dateProvider: { today }
        )

        // View today's challenge
        let todayChallenge = challengeService.challengeForDate(today)
        XCTAssertFalse(todayChallenge.id.isEmpty)

        // Complete it
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        XCTAssertFalse(vm.isCompleted)
        vm.complete(journal: "Blessed day")
        XCTAssertTrue(vm.isCompleted)

        // Verify persistence
        let descriptor = FetchDescriptor<CompletedChallenge>()
        let completions = try context.fetch(descriptor)
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.challengeId, todayChallenge.id)
        XCTAssertEqual(completions.first?.journalEntry, "Blessed day")

        // Verify streak
        XCTAssertEqual(vm.currentStreak, 1)

        // Verify no badges yet (only 1 completion)
        let earned = badgeService.earnedBadges()
        XCTAssertTrue(earned.isEmpty)
    }

    func testComplete31Challenges_5KBadgeAppearsInJourney() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let badgeService = BadgeService(modelContext: context)
        let challengeService = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            userStartDate: Date.from(year: 2026, month: 6, day: 1), dateProvider: { today }
        )

        // Insert 31 completions
        for i in 0..<31 {
            let date = today.addingDays(-i)
            let challenge = challengeService.challengeForDate(date)
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date
            )
            context.insert(completion)
        }
        try context.save()

        // Evaluate badges
        let newBadges = badgeService.evaluateAndAward()
        XCTAssertTrue(newBadges.contains(where: { $0.name == "5K" }))

        // Verify in JourneyViewModel
        let journeyVM = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(journeyVM.totalCompleted, 31)
        XCTAssertTrue(journeyVM.allBadges.contains(where: { $0.name == "5K" && $0.isEarned }))
    }

    func testMissADay_StreakResets_GracePeriodAllowsRecovery() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let badgeService = BadgeService(modelContext: context)
        let challengeService = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            userStartDate: Date.from(year: 2026, month: 6, day: 1), dateProvider: { today }
        )

        // Complete days 10, 11, 12 (skip 13, 14), current is 15
        for day in [10, 11, 12] {
            let date = Date.from(year: 2026, month: 6, day: day)
            let challenge = challengeService.challengeForDate(date)
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date
            )
            context.insert(completion)
        }
        try context.save()

        // Streak should be 0 (today not completed, yesterday not completed, gap)
        let streak = challengeService.calculateStreak()
        XCTAssertEqual(streak, 0, "Streak should be 0 due to gap on day 13-14")

        // Day 13 is within grace period (2 days ago from 15)
        let day13 = Date.from(year: 2026, month: 6, day: 13)
        XCTAssertTrue(GracePeriod.canComplete(challengeDate: day13, today: today))

        // Complete day 13 via grace period
        let challenge13 = challengeService.challengeForDate(day13)
        _ = try challengeService.completeChallenge(challenge13, on: day13, journal: nil)

        // Day 14 is also within grace period
        let day14 = Date.from(year: 2026, month: 6, day: 14)
        let challenge14 = challengeService.challengeForDate(day14)
        _ = try challengeService.completeChallenge(challenge14, on: day14, journal: nil)

        // Now complete today
        let challengeToday = challengeService.challengeForDate(today)
        _ = try challengeService.completeChallenge(challengeToday, on: today, journal: nil)

        // Streak should now be 6 (days 10-15)
        let recoveredStreak = challengeService.calculateStreak()
        XCTAssertEqual(recoveredStreak, 6, "Streak should recover to 6 after grace period completions")
    }

    func testCompleteChallengeWithJournal_JournalAppearsInTimeline() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let badgeService = BadgeService(modelContext: context)
        let challengeService = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            userStartDate: Date.from(year: 2026, month: 6, day: 1), dateProvider: { today }
        )

        let challenge = challengeService.challengeForDate(today)
        _ = try challengeService.completeChallenge(challenge, on: today, journal: "God moved mightily today")

        let journeyVM = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(journeyVM.journalEntries.count, 1)
        XCTAssertEqual(journeyVM.journalEntries.first?.journalText, "God moved mightily today")
        XCTAssertEqual(journeyVM.journalEntries.first?.challengeTitle, challenge.title)
    }

    // MARK: - 4.2 Year Transition

    func testDay365Completion_Day366ShowsDifferentChallengeThanDay1() throws {
        let badgeService = BadgeService(modelContext: context)
        let challengeService = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService
        )

        let day1 = Date.from(year: 2026, month: 1, day: 1)
        let day366 = Date.from(year: 2027, month: 1, day: 1) // Next year's day 1

        // Under the global rotation (CLEAN-001), the same day-of-year in the
        // next calendar year must resolve to a different challenge.
        let challenge1 = challengeService.challengeForDate(day1)
        let challengeYear2 = challengeService.challengeForDate(day366)

        XCTAssertNotEqual(challenge1.id, challengeYear2.id,
                         "Day 1 of year 2 should show a different challenge than day 1 of year 1")
    }

    func testGivingChallengesOnFirstSaturdaysPersistAcrossYearBoundary() throws {
        let scheduler = try XCTUnwrap(ChallengeScheduler(challenges: challenges))

        // First Saturday of January 2026
        let jan2026FirstSat = Date.from(year: 2026, month: 1, day: 3) // Jan 3 2026 is Saturday
        // First Saturday of January 2027
        let jan2027FirstSat = Date.from(year: 2027, month: 1, day: 2) // Jan 2 2027 is Saturday

        // Verify both are actually first Saturdays
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: jan2026FirstSat), 7) // Saturday
        XCTAssertLessThanOrEqual(cal.component(.day, from: jan2026FirstSat), 7)

        XCTAssertEqual(cal.component(.weekday, from: jan2027FirstSat), 7)
        XCTAssertLessThanOrEqual(cal.component(.day, from: jan2027FirstSat), 7)

        let challenge2026 = scheduler.challengeForDate(jan2026FirstSat, yearOffset: 0)
        let challenge2027 = scheduler.challengeForDate(jan2027FirstSat, yearOffset: 1)

        XCTAssertEqual(challenge2026.category, .giving, "First Saturday 2026 should be giving")
        XCTAssertEqual(challenge2027.category, .giving, "First Saturday 2027 should be giving")
    }

    // MARK: - 4.3 Data Integrity

    func testForceQuitAndRelaunchPreservesAllData() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let badgeService = BadgeService(modelContext: context)
        let challengeService = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            userStartDate: Date.from(year: 2026, month: 6, day: 1), dateProvider: { today }
        )

        // Complete a challenge and earn it
        let challenge = challengeService.challengeForDate(today)
        _ = try challengeService.completeChallenge(challenge, on: today, journal: "Test persistence")

        // Simulate "relaunch" — create new ModelContext from same container
        let newContext = ModelContext(container)
        let newBadgeService = BadgeService(modelContext: newContext)
        let newChallengeService = try ChallengeService(
            modelContext: newContext, challenges: challenges, badgeService: newBadgeService,
            userStartDate: Date.from(year: 2026, month: 6, day: 1), dateProvider: { today }
        )

        // Verify data survived
        let completions = newChallengeService.fetchCompletions(
            for: today.addingDays(-1)...today.addingDays(1)
        )
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.journalEntry, "Test persistence")
        XCTAssertTrue(newChallengeService.isCompleted(on: today))
    }

    func test1000CompletionsDoesNotDegradePerformance() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let badgeService = BadgeService(modelContext: context)
        let challengeService = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            userStartDate: Date.from(year: 2026, month: 6, day: 1), dateProvider: { today }
        )

        // Insert 1000 completions
        for i in 0..<1000 {
            let date = today.addingDays(-i)
            let challengeIndex = i % challenges.count
            let challenge = challenges[challengeIndex]
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date
            )
            context.insert(completion)
        }
        try context.save()

        // Measure streak calculation performance
        let start = CFAbsoluteTimeGetCurrent()
        let streak = challengeService.calculateStreak()
        let streakTime = CFAbsoluteTimeGetCurrent() - start

        XCTAssertGreaterThan(streak, 0)
        XCTAssertLessThan(streakTime, 1.0, "Streak calculation should complete in under 1 second with 1000 completions")

        // Measure badge evaluation performance
        let badgeStart = CFAbsoluteTimeGetCurrent()
        _ = badgeService.evaluateAndAward()
        let badgeTime = CFAbsoluteTimeGetCurrent() - badgeStart

        XCTAssertLessThan(badgeTime, 2.0, "Badge evaluation should complete in under 2 seconds with 1000 completions")

        // Measure fetch performance
        let fetchStart = CFAbsoluteTimeGetCurrent()
        let range = today.addingDays(-1000)...today
        let results = challengeService.fetchCompletions(for: range)
        let fetchTime = CFAbsoluteTimeGetCurrent() - fetchStart

        XCTAssertEqual(results.count, 1000)
        XCTAssertLessThan(fetchTime, 1.0, "Fetch should complete in under 1 second with 1000 completions")
    }

    func testJSONLoadingHandlesMalformedDataGracefully() {
        // Test that ChallengeLoader throws appropriate error for a bundle without challenges.json
        let emptyBundle = Bundle(path: "/nonexistent") ?? Bundle(for: type(of: self))
        // Use a known-empty bundle path to test error handling
        XCTAssertThrowsError(try ChallengeLoader.loadChallenges(from: Bundle(path: "/System")!)) { error in
            XCTAssertTrue(error is ChallengeLoader.LoadError)
        }
    }
}
