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

        // Give async Task time to complete
        try? await Task.sleep(for: .milliseconds(100))

        let morning = mockCenter.addedRequests.first { $0.identifier == "morning_challenge" }
        XCTAssertNotNil(morning, "Morning notification should be scheduled")
    }

    func testScheduleAllNotificationsCreatesEveningNotification() async {
        let profile = UserProfile(
            morningNotificationsEnabled: false,
            eveningRemindersEnabled: true
        )
        service.scheduleAllNotifications(profile: profile)

        try? await Task.sleep(for: .milliseconds(100))

        let evening = mockCenter.addedRequests.first { $0.identifier == "evening_reminder" }
        XCTAssertNotNil(evening, "Evening notification should be scheduled")
    }

    func testCancelTodayRemindersRemovesPendingNotifications() async {
        let profile = UserProfile(
            morningNotificationsEnabled: true,
            eveningRemindersEnabled: true
        )
        service.scheduleAllNotifications(profile: profile)
        try? await Task.sleep(for: .milliseconds(100))

        service.cancelTodayReminders()

        XCTAssertTrue(mockCenter.removedIdentifiers.contains("evening_reminder"))
        XCTAssertTrue(mockCenter.removedIdentifiers.contains("streak_warning"))
    }

    func testScheduleStreakWarningCreatesNotificationOnlyIfStreakGTE7() async {
        // Streak < 7: should NOT schedule
        service.scheduleStreakWarning(streak: 5)
        try? await Task.sleep(for: .milliseconds(100))

        let noWarning = mockCenter.addedRequests.first { $0.identifier == "streak_warning" }
        XCTAssertNil(noWarning, "Streak < 7 should not schedule warning")

        // Streak >= 7: should schedule
        service.scheduleStreakWarning(streak: 10)
        try? await Task.sleep(for: .milliseconds(100))

        let warning = mockCenter.addedRequests.first { $0.identifier == "streak_warning" }
        XCTAssertNotNil(warning, "Streak >= 7 should schedule warning")
    }

    func testNotificationsRespectUserDisabledPreferences() async {
        let profile = UserProfile(
            morningNotificationsEnabled: false,
            eveningRemindersEnabled: false
        )
        service.scheduleAllNotifications(profile: profile)
        try? await Task.sleep(for: .milliseconds(100))

        let morning = mockCenter.addedRequests.first { $0.identifier == "morning_challenge" }
        let evening = mockCenter.addedRequests.first { $0.identifier == "evening_reminder" }
        XCTAssertNil(morning, "Disabled morning should not be scheduled")
        XCTAssertNil(evening, "Disabled evening should not be scheduled")
    }
}
