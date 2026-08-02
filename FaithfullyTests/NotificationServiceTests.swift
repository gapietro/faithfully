import XCTest
import UserNotifications
@testable import Faithfully

/// Lock-guarded because `NotificationCenterProtocol` is `Sendable`: the real
/// center is reached from the serialized operation chain, which runs off the
/// caller's context, and the concurrency stress tests hit this mock from many
/// tasks at once. An unguarded mock would make those tests flaky rather than
/// meaningful.
final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var _permissionGranted = true
    private var _requestAuthorizationCalled = false
    private var _addedRequests: [UNNotificationRequest] = []
    private var _removedIdentifiers: [String] = []

    var permissionGranted: Bool {
        get { lock.withLock { _permissionGranted } }
        set { lock.withLock { _permissionGranted = newValue } }
    }
    var requestAuthorizationCalled: Bool { lock.withLock { _requestAuthorizationCalled } }
    var addedRequests: [UNNotificationRequest] { lock.withLock { _addedRequests } }
    var removedIdentifiers: [String] { lock.withLock { _removedIdentifiers } }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        lock.withLock {
            _requestAuthorizationCalled = true
            return _permissionGranted
        }
    }

    func add(_ request: UNNotificationRequest) async throws {
        // Mirror UNUserNotificationCenter: adding with an existing identifier
        // replaces the pending request rather than stacking a duplicate.
        lock.withLock {
            _addedRequests.removeAll { $0.identifier == request.identifier }
            _addedRequests.append(request)
        }
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        lock.withLock {
            _removedIdentifiers.append(contentsOf: identifiers)
            _addedRequests.removeAll { identifiers.contains($0.identifier) }
        }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        lock.withLock { _addedRequests }
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

    func testScheduleAllPreservesPendingBadgeCelebration() async {
        let badge = EarnedBadge(badgeName: "streak_7", badgeType: .streak, threshold: 7)
        service.scheduleBadgeCelebration(badge, profile: UserProfile(badgeNotificationsEnabled: true))

        // A refresh (settings change / foreground / launch) before the badge's
        // 1s trigger fires must not swallow the celebration.
        service.scheduleAllNotifications(profile: UserProfile(
            morningNotificationsEnabled: true,
            eveningRemindersEnabled: true
        ))
        await service.waitForPendingOperations()

        XCTAssertNotNil(mockCenter.addedRequests.first { $0.identifier == "badge_streak_7" },
                        "Re-arming daily notifications must preserve a pending badge celebration")
        XCTAssertNotNil(mockCenter.addedRequests.first { $0.identifier == "morning_challenge" })
        XCTAssertNotNil(mockCenter.addedRequests.first { $0.identifier == "evening_reminder" })
    }

    func testScheduleAllReplacesRatherThanStacksDailyNotifications() async {
        let profile = UserProfile(
            morningNotificationsEnabled: true,
            eveningRemindersEnabled: true
        )
        service.scheduleAllNotifications(profile: profile)
        service.scheduleAllNotifications(profile: profile)
        await service.waitForPendingOperations()

        XCTAssertEqual(mockCenter.addedRequests.filter { $0.identifier == "morning_challenge" }.count, 1)
        XCTAssertEqual(mockCenter.addedRequests.filter { $0.identifier == "evening_reminder" }.count, 1)
    }

    func testScheduleAllRemovesStaleStreakWarning() async {
        service.scheduleStreakWarning(streak: 10, profile: UserProfile(streakWarningsEnabled: true))
        await service.waitForPendingOperations()
        XCTAssertNotNil(mockCenter.addedRequests.first { $0.identifier == "streak_warning" })

        // A refresh after the preference is turned off must clear the armed
        // warning; refreshNotifications only re-adds it when still eligible.
        service.scheduleAllNotifications(profile: UserProfile(streakWarningsEnabled: false))
        await service.waitForPendingOperations()

        XCTAssertNil(mockCenter.addedRequests.first { $0.identifier == "streak_warning" },
                     "Re-arming daily notifications must clear a previously armed streak warning")
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

    // MARK: - Concurrency stress (CLEAN-006)

    private func makeBadge(_ name: String) -> EarnedBadge {
        EarnedBadge(badgeName: name, badgeType: .journey, threshold: 1)
    }

    /// The chain used to be linked through unguarded mutable state: two callers
    /// could read the same predecessor, and one assignment overwrote the other,
    /// dropping that operation out of the chain entirely. With 200 concurrent
    /// enqueues, some adds went missing and `waitForPendingOperations` returned
    /// before they ran.
    func testConcurrentEnqueuesNeverDropAnOperation() async {
        let profile = UserProfile()
        let count = 200
        let service = self.service!
        let badges = (0..<count).map { makeBadge("stress_\($0)") }

        await withTaskGroup(of: Void.self) { group in
            for badge in badges {
                group.addTask { service.scheduleBadgeCelebration(badge, profile: profile) }
            }
        }
        await service.waitForPendingOperations()

        XCTAssertEqual(
            mockCenter.addedRequests.count, count,
            "Every concurrently enqueued operation must run and be awaited"
        )
        let identifiers = Set(mockCenter.addedRequests.map(\.identifier))
        XCTAssertEqual(identifiers.count, count, "No operation may be lost or duplicated")
    }

    /// Overlapping authorization, scheduling, cancellation, and settings changes
    /// — the four paths the app actually interleaves (permission callback, scene
    /// foreground, completion, settings save).
    func testOverlappingAuthorizeScheduleCancelAndSettingsChangesSettleDeterministically() async {
        let service = self.service!
        let profiles = (0..<40).map { index -> UserProfile in
            let profile = UserProfile()
            // Alternate the settings each iteration, as a user toggling would.
            profile.morningNotificationsEnabled = index % 2 == 0
            profile.eveningRemindersEnabled = true
            profile.streakWarningsEnabled = true
            return profile
        }

        await withTaskGroup(of: Void.self) { group in
            for profile in profiles {
                group.addTask { _ = await service.requestPermission() }
                group.addTask { service.scheduleAllNotifications(profile: profile) }
                group.addTask { service.scheduleStreakWarning(streak: 10, profile: profile) }
                group.addTask { service.cancelTodayReminders() }
            }
        }
        await service.waitForPendingOperations()

        // The interleaving is arbitrary, but the run must terminate, drain fully,
        // and leave the store self-consistent — never a torn or duplicated set.
        let identifiers = mockCenter.addedRequests.map(\.identifier)
        XCTAssertEqual(Set(identifiers).count, identifiers.count,
                       "Pending requests must never contain duplicate identifiers")
        XCTAssertTrue(mockCenter.requestAuthorizationCalled)
    }

    /// The ordering guarantee the chain exists for: a cancel issued after a
    /// schedule must win, even though the schedule's `add` is async. If the chain
    /// drops links, the schedule can land after the cancel and resurrect a
    /// reminder the user already dismissed by completing the day.
    func testCancelIssuedAfterScheduleIsNeverOvertaken() async {
        let profile = UserProfile()
        profile.morningNotificationsEnabled = true
        profile.eveningRemindersEnabled = true

        for _ in 0..<50 {
            service.scheduleAllNotifications(profile: profile)
            service.cancelTodayReminders()
        }
        await service.waitForPendingOperations()

        let pending = Set(mockCenter.addedRequests.map(\.identifier))
        XCTAssertFalse(pending.contains("evening_reminder"),
                       "A cancel issued after a schedule must not be overtaken by the schedule's add")
        XCTAssertFalse(pending.contains("streak_warning"))
        XCTAssertTrue(pending.contains("morning_challenge"),
                      "Cancelling today's reminders must leave the morning notification alone")
    }

    func testWaitForPendingOperationsDrainsWorkEnqueuedFromManyTasks() async {
        let profile = UserProfile()
        let service = self.service!
        let badges = (0..<50).map { makeBadge("drain_\($0)") }

        await withTaskGroup(of: Void.self) { group in
            for badge in badges {
                group.addTask { service.scheduleBadgeCelebration(badge, profile: profile) }
            }
        }
        await service.waitForPendingOperations()

        // No second drain, no polling: one await must be enough.
        XCTAssertEqual(mockCenter.addedRequests.count, 50)
    }
}
