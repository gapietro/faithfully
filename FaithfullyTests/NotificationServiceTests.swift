import XCTest
import UserNotifications
@testable import Faithfully

final class MockNotificationCenter: NotificationCenterProtocol {
    var permissionGranted = true
    var requestAuthorizationCalled = false
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []
    var allRemoved = false

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCalled = true
        return permissionGranted
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removeAllPendingNotificationRequests() {
        allRemoved = true
        addedRequests.removeAll()
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        addedRequests.removeAll { identifiers.contains($0.identifier) }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        return addedRequests
    }
}

final class NotificationServiceTests: XCTestCase {

    var mockCenter: MockNotificationCenter!
    var service: NotificationService!

    override func setUp() {
        mockCenter = MockNotificationCenter()
        service = NotificationService(center: mockCenter)
    }

    func testRequestPermissionCallsUNUserNotificationCenter() async {
        let result = await service.requestPermission()
        XCTAssertTrue(mockCenter.requestAuthorizationCalled)
        XCTAssertTrue(result)
    }

    func testScheduleAllNotificationsCreatesMorningNotification() async {
        let profile = UserProfile(
            morningNotificationsEnabled: true,
            eveningRemindersEnabled: false
        )
        service.scheduleAllNotifications(profile: profile)
        await service.waitForPendingOperations()

        let morning = mockCenter.addedRequests.first { $0.identifier == "morning_challenge" }
        XCTAssertNotNil(morning, "Morning notification should be scheduled")
    }

    func testScheduleAllNotificationsCreatesEveningNotification() async {
        let profile = UserProfile(
            morningNotificationsEnabled: false,
            eveningRemindersEnabled: true
        )
        service.scheduleAllNotifications(profile: profile)
        await service.waitForPendingOperations()

        let evening = mockCenter.addedRequests.first { $0.identifier == "evening_reminder" }
        XCTAssertNotNil(evening, "Evening notification should be scheduled")
    }

    func testScheduledTriggersUseProfileTimes() async throws {
        let calendar = Calendar.current
        let profile = UserProfile(
            morningNotificationTime: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 9, minute: 30))),
            eveningReminderTime: try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 21, minute: 15))),
            morningNotificationsEnabled: true,
            eveningRemindersEnabled: true
        )
        service.scheduleAllNotifications(profile: profile)
        await service.waitForPendingOperations()

        let morning = try XCTUnwrap(mockCenter.addedRequests.first { $0.identifier == "morning_challenge" })
        let morningTrigger = try XCTUnwrap(morning.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(morningTrigger.dateComponents.hour, 9)
        XCTAssertEqual(morningTrigger.dateComponents.minute, 30)
        XCTAssertTrue(morningTrigger.repeats)

        let evening = try XCTUnwrap(mockCenter.addedRequests.first { $0.identifier == "evening_reminder" })
        let eveningTrigger = try XCTUnwrap(evening.trigger as? UNCalendarNotificationTrigger)
        XCTAssertEqual(eveningTrigger.dateComponents.hour, 21)
        XCTAssertEqual(eveningTrigger.dateComponents.minute, 15)
    }

    func testCancelTodayRemindersRemovesPendingNotifications() async {
        let profile = UserProfile(
            morningNotificationsEnabled: true,
            eveningRemindersEnabled: true
        )
        service.scheduleAllNotifications(profile: profile)
        service.cancelTodayReminders()
        await service.waitForPendingOperations()

        XCTAssertTrue(mockCenter.removedIdentifiers.contains("evening_reminder"))
        XCTAssertTrue(mockCenter.removedIdentifiers.contains("streak_warning"))
        XCTAssertNil(mockCenter.addedRequests.first { $0.identifier == "evening_reminder" },
                     "A cancel issued after a schedule must win, even though adds are async")
    }

    func testScheduleStreakWarningCreatesNotificationOnlyIfStreakGTE7() async {
        let profile = UserProfile(streakWarningsEnabled: true)

        // Streak < 7: should NOT schedule
        service.scheduleStreakWarning(streak: 5, profile: profile)
        await service.waitForPendingOperations()

        let noWarning = mockCenter.addedRequests.first { $0.identifier == "streak_warning" }
        XCTAssertNil(noWarning, "Streak < 7 should not schedule warning")

        // Streak >= 7: should schedule
        service.scheduleStreakWarning(streak: 10, profile: profile)
        await service.waitForPendingOperations()

        let warning = mockCenter.addedRequests.first { $0.identifier == "streak_warning" }
        XCTAssertNotNil(warning, "Streak >= 7 should schedule warning")
    }

    func testStreakWarningNotScheduledWhenPreferenceDisabled() async {
        let profile = UserProfile(streakWarningsEnabled: false)
        service.scheduleStreakWarning(streak: 10, profile: profile)
        await service.waitForPendingOperations()

        XCTAssertNil(mockCenter.addedRequests.first { $0.identifier == "streak_warning" },
                     "Streak warnings disabled in preferences must never schedule")
    }

    func testBadgeCelebrationScheduledOnlyWhenPreferenceEnabled() async {
        let badge = EarnedBadge(badgeName: "streak_7", badgeType: .streak, threshold: 7)

        service.scheduleBadgeCelebration(badge, profile: UserProfile(badgeNotificationsEnabled: false))
        await service.waitForPendingOperations()
        XCTAssertTrue(mockCenter.addedRequests.isEmpty,
                      "Badge celebrations disabled in preferences must never schedule")

        service.scheduleBadgeCelebration(badge, profile: UserProfile(badgeNotificationsEnabled: true))
        await service.waitForPendingOperations()
        XCTAssertNotNil(mockCenter.addedRequests.first { $0.identifier == "badge_streak_7" })
    }

    func testNotificationsRespectUserDisabledPreferences() async {
        let profile = UserProfile(
            morningNotificationsEnabled: false,
            eveningRemindersEnabled: false
        )
        service.scheduleAllNotifications(profile: profile)
        await service.waitForPendingOperations()

        let morning = mockCenter.addedRequests.first { $0.identifier == "morning_challenge" }
        let evening = mockCenter.addedRequests.first { $0.identifier == "evening_reminder" }
        XCTAssertNil(morning, "Disabled morning should not be scheduled")
        XCTAssertNil(evening, "Disabled evening should not be scheduled")
    }
}
