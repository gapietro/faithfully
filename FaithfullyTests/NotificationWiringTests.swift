import XCTest
import SwiftData
import UserNotifications
@testable import Faithfully

/// Sprint B end-to-end wiring: the composition root drives notification
/// scheduling from completions, settings changes, and the foreground refresh
/// path, and settings changes propagate to the other tabs.
final class NotificationWiringTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var mockCenter: MockNotificationCenter!
    var notificationService: NotificationService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        mockCenter = MockNotificationCenter()
        notificationService = NotificationService(center: mockCenter)
    }

    /// Seeds a long-standing profile before bootstrapping. These tests build
    /// streaks out of past days, which a user enrolling on `today` would not be
    /// eligible for (CLEAN-002).
    private func makeServices(today: Date) throws -> AppServices {
        if try context.fetch(FetchDescriptor<UserProfile>()).isEmpty {
            context.insert(UserProfile(startDate: TestHelpers.longEnrolledDate))
            try context.save()
        }
        let env = AppEnvironment(
            modelContext: context,
            loadChallenges: { self.challenges },
            notificationService: notificationService,
            dateProvider: { today }
        )
        return try XCTUnwrap(env.services)
    }

    private func insertCompletions(endingOn lastDay: Date, count: Int, service: ChallengeServiceProtocol) throws {
        for i in 0..<count {
            let date = lastDay.addingDays(-i)
            let challenge = service.challengeForDate(date)
            context.insert(CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date.startOfDay
            ))
        }
        try context.save()
    }

    private func pending(_ identifier: String) -> UNNotificationRequest? {
        mockCenter.addedRequests.first { $0.identifier == identifier }
    }

    // MARK: - #7 Completion cancels today's reminders

    func testCompletingTodayCancelsEveningReminderAndStreakWarning() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)
        services.refreshNotifications()
        await notificationService.waitForPendingOperations()
        XCTAssertNotNil(pending("evening_reminder"))

        services.dailyWalkViewModel.complete(journal: nil)
        await notificationService.waitForPendingOperations()

        XCTAssertNil(pending("evening_reminder"),
                     "Completing today must cancel the evening reminder")
        XCTAssertNil(pending("streak_warning"),
                     "Completing today must cancel the streak warning")
        XCTAssertNotNil(pending("morning_challenge"),
                        "The repeating morning notification stays scheduled")
    }

    func testGraceCompletionOfPastDayKeepsTodayReminders() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)
        services.refreshNotifications()
        await notificationService.waitForPendingOperations()

        let graceDay = try XCTUnwrap(services.calendarViewModel.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 13
        })
        services.calendarViewModel.completeGracePeriod(graceDay, journal: nil)
        await notificationService.waitForPendingOperations()

        XCTAssertNotNil(pending("evening_reminder"),
                        "Recovering a past day must not cancel today's evening reminder")
    }

    func testGraceRecoveryLiftingStreakPastSevenArmsStreakWarning() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)
        // Completions on the 7th–12th and the 14th: the gap on the 13th holds
        // the streak at 1 until a grace recovery bridges it to 8.
        try insertCompletions(endingOn: today.addingDays(-3), count: 6, service: services.challengeService)
        try insertCompletions(endingOn: today.addingDays(-1), count: 1, service: services.challengeService)
        services.refreshNotifications()
        await notificationService.waitForPendingOperations()
        XCTAssertNil(pending("streak_warning"),
                     "A broken streak below 7 must not arm the warning")

        let graceDay = try XCTUnwrap(services.calendarViewModel.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 13
        })
        services.calendarViewModel.completeGracePeriod(graceDay, journal: nil)
        await notificationService.waitForPendingOperations()

        XCTAssertNotNil(pending("streak_warning"),
                        "A grace recovery that lifts the streak past 7 with today still open must arm the warning immediately, not wait for the next foreground pass")
        XCTAssertNotNil(pending("evening_reminder"),
                        "Today is still incomplete, so the evening reminder stays")
    }

    // MARK: - #7 Settings changes reschedule

    func testDisablingEveningReminderInSettingsRemovesItFromPending() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)
        services.refreshNotifications()
        await notificationService.waitForPendingOperations()
        XCTAssertNotNil(pending("evening_reminder"))

        services.settingsViewModel.toggleEveningReminders(false)
        await notificationService.waitForPendingOperations()

        XCTAssertNil(pending("evening_reminder"))
        XCTAssertNotNil(pending("morning_challenge"))
    }

    func testChangingMorningTimeInSettingsReschedulesWithNewTime() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)
        let newTime = try XCTUnwrap(Calendar.current.date(
            from: DateComponents(year: 2026, month: 6, day: 15, hour: 5, minute: 55)
        ))

        services.settingsViewModel.updateMorningTime(newTime)
        await notificationService.waitForPendingOperations()

        let trigger = try XCTUnwrap(pending("morning_challenge")?.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(trigger.dateComponents.hour, 5)
        XCTAssertEqual(trigger.dateComponents.minute, 55)
    }

    // MARK: - #7 Streak warning from the daily schedule path

    func testForegroundRefreshSchedulesStreakWarningWhenEligible() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)
        try insertCompletions(endingOn: today.addingDays(-1), count: 8, service: services.challengeService)

        services.refreshForCurrentDate()
        await notificationService.waitForPendingOperations()

        XCTAssertNotNil(pending("streak_warning"),
                        "Streak >= 7 with today incomplete must arm the warning")
    }

    func testStreakWarningNotArmedWhenPreferenceDisabled() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)
        try insertCompletions(endingOn: today.addingDays(-1), count: 8, service: services.challengeService)
        services.settingsViewModel.toggleStreakWarnings(false)

        services.refreshForCurrentDate()
        await notificationService.waitForPendingOperations()

        XCTAssertNil(pending("streak_warning"))
    }

    func testStreakWarningNotArmedWhenTodayAlreadyCompleted() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)
        try insertCompletions(endingOn: today, count: 8, service: services.challengeService)

        services.refreshForCurrentDate()
        await notificationService.waitForPendingOperations()

        XCTAssertNil(pending("streak_warning"),
                     "No streak warning when today is already done")
        XCTAssertNil(pending("evening_reminder"),
                     "No evening nag when today is already done")
    }

    // MARK: - #7 Badge celebration honors preference

    func testBadgeAwardSchedulesCelebrationOnlyWhenEnabled() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        var services = try makeServices(today: today)
        // 30 prior completions so the 31st awards the journey badge.
        try insertCompletions(endingOn: today.addingDays(-1), count: 30, service: services.challengeService)

        services.settingsViewModel.toggleBadgeNotifications(false)
        services.dailyWalkViewModel.complete(journal: nil)
        await notificationService.waitForPendingOperations()
        XCTAssertTrue(mockCenter.addedRequests.filter { $0.identifier.hasPrefix("badge_") }.isEmpty,
                      "Badge celebrations disabled must not schedule")

        // Fresh graph on a fresh store: enabled path schedules.
        try setUpWithError()
        services = try makeServices(today: today)
        try insertCompletions(endingOn: today.addingDays(-1), count: 30, service: services.challengeService)

        services.dailyWalkViewModel.complete(journal: nil)
        await notificationService.waitForPendingOperations()
        XCTAssertFalse(mockCenter.addedRequests.filter { $0.identifier.hasPrefix("badge_") }.isEmpty,
                       "A newly earned badge must schedule a celebration when enabled")
    }

    func testRefreshBeforeBadgeTriggerFiresPreservesCelebration() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)
        // 30 prior completions so the 31st awards the journey badge.
        try insertCompletions(endingOn: today.addingDays(-1), count: 30, service: services.challengeService)

        services.dailyWalkViewModel.complete(journal: nil)
        // A settings-change / foreground refresh landing inside the badge's 1s
        // trigger window must not swallow the pending celebration.
        services.refreshNotifications()
        await notificationService.waitForPendingOperations()

        XCTAssertFalse(mockCenter.addedRequests.filter { $0.identifier.hasPrefix("badge_") }.isEmpty,
                       "A refresh before the badge push fires must leave it pending")
    }

    // MARK: - #7 Onboarding permission

    func testOnboardingFinishRequestsPermissionAndSchedules() async throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        let services = try makeServices(today: today)

        await services.requestNotificationPermissionAndSchedule()
        await notificationService.waitForPendingOperations()

        XCTAssertTrue(mockCenter.requestAuthorizationCalled)
        XCTAssertNotNil(pending("morning_challenge"))
        XCTAssertNotNil(pending("evening_reminder"))
    }

    // MARK: - #8 Translation propagates to Daily Walk

    func testDailyWalkStartsWithProfileTranslation() throws {
        context.insert(UserProfile(preferredTranslation: .kjv))
        try context.save()

        let services = try makeServices(today: Date.from(year: 2026, month: 6, day: 15))
        XCTAssertEqual(services.dailyWalkViewModel.translation, .kjv,
                       "Daily Walk must load the persisted translation, not default to WEB")
    }

    func testChangingTranslationInSettingsUpdatesDailyWalkLive() throws {
        let services = try makeServices(today: Date.from(year: 2026, month: 6, day: 15))
        XCTAssertEqual(services.dailyWalkViewModel.translation, .web)

        services.settingsViewModel.updateTranslation(.kjv)

        XCTAssertEqual(services.dailyWalkViewModel.translation, .kjv,
                       "A Settings translation change must reach Daily Walk without relaunch")
        XCTAssertEqual(services.dailyWalkViewModel.scriptureText,
                       services.dailyWalkViewModel.todayChallenge.scriptureText(for: .kjv))
    }
}
