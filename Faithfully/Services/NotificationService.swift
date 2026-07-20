import Foundation
import UserNotifications

protocol NotificationServiceProtocol {
    func requestPermission() async -> Bool
    func scheduleAllNotifications(profile: UserProfile)
    func cancelTodayReminders()
    func scheduleStreakWarning(streak: Int, profile: UserProfile)
    func scheduleBadgeCelebration(_ badge: EarnedBadge, profile: UserProfile)
}

protocol NotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}

final class NotificationService: NotificationServiceProtocol {
    let center: NotificationCenterProtocol

    /// All schedule/cancel work runs through this serial chain so a cancel
    /// issued after a schedule can never be overtaken by the schedule's async
    /// add — e.g. completing today right after a settings change must leave the
    /// evening reminder cancelled, not resurrected.
    private var operationQueue: Task<Void, Never> = Task {}

    init(center: NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func requestPermission() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return false
        }
    }

    func scheduleAllNotifications(profile: UserProfile) {
        // Snapshot the model's values before hopping off the caller's context.
        let morning = profile.morningNotificationsEnabled
            ? Self.makeDailyRequest(
                identifier: "morning_challenge",
                title: "Your Daily Walk",
                body: "Today's challenge is waiting for you.",
                time: profile.morningNotificationTime
            )
            : nil
        let evening = profile.eveningRemindersEnabled
            ? Self.makeDailyRequest(
                identifier: "evening_reminder",
                title: "Don't Forget Your Walk",
                body: "You haven't completed today's challenge yet.",
                time: profile.eveningReminderTime
            )
            : nil

        enqueue { [center] in
            // Remove only the recurring daily ids, never the whole pending set:
            // a refresh (settings change, foreground, launch) must not swallow a
            // one-shot badge_* celebration still waiting on its 1s trigger.
            center.removePendingNotificationRequests(withIdentifiers: [
                "morning_challenge",
                "evening_reminder",
                "streak_warning"
            ])
            if let morning { try? await center.add(morning) }
            if let evening { try? await center.add(evening) }
        }
    }

    func cancelTodayReminders() {
        enqueue { [center] in
            center.removePendingNotificationRequests(withIdentifiers: [
                "evening_reminder",
                "streak_warning"
            ])
        }
    }

    func scheduleStreakWarning(streak: Int, profile: UserProfile) {
        guard profile.streakWarningsEnabled, streak >= 7 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Protect Your Streak!"
        content.body = "Don't break your \(streak)-day streak!"
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = 21
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: "streak_warning", content: content, trigger: trigger)
        enqueue { [center] in try? await center.add(request) }
    }

    func scheduleBadgeCelebration(_ badge: EarnedBadge, profile: UserProfile) {
        guard profile.badgeNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Badge Earned!"
        content.body = "You earned the \(badge.badgeName) badge!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "badge_\(badge.badgeName)", content: content, trigger: trigger)
        enqueue { [center] in try? await center.add(request) }
    }

    /// Awaits every operation enqueued so far. Exposed for tests, which need
    /// the async adds to have landed before asserting on the mock center.
    func waitForPendingOperations() async {
        await operationQueue.value
    }

    // MARK: - Private

    private func enqueue(_ operation: @escaping () async -> Void) {
        operationQueue = Task { [previous = operationQueue] in
            await previous.value
            await operation()
        }
    }

    private static func makeDailyRequest(identifier: String, title: String, body: String, time: Date) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }
}
