import Foundation
import UserNotifications

protocol NotificationServiceProtocol {
    func requestPermission() async -> Bool
    func scheduleAllNotifications(profile: UserProfile)
    func cancelTodayReminders()
    func scheduleStreakWarning(streak: Int)
    func scheduleBadgeCelebration(_ badge: EarnedBadge)
}

protocol NotificationCenterProtocol {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removeAllPendingNotificationRequests()
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
        center.removeAllPendingNotificationRequests()

        if profile.morningNotificationsEnabled {
            scheduleMorningNotification(at: profile.morningNotificationTime)
        }

        if profile.eveningRemindersEnabled {
            scheduleEveningReminder(at: profile.eveningReminderTime)
        }
    }

    func cancelTodayReminders() {
        center.removePendingNotificationRequests(withIdentifiers: [
            "evening_reminder",
            "streak_warning"
        ])
    }

    func scheduleStreakWarning(streak: Int) {
        guard streak >= 7 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Protect Your Streak!"
        content.body = "Don't break your \(streak)-day streak!"
        content.sound = .default

        var components = Calendar.current.dateComponents([.year, .month, .day], from: .now)
        components.hour = 21
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: "streak_warning", content: content, trigger: trigger)
        Task { try? await center.add(request) }
    }

    func scheduleBadgeCelebration(_ badge: EarnedBadge) {
        let content = UNMutableNotificationContent()
        content.title = "Badge Earned!"
        content.body = "You earned the \(badge.badgeName) badge!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "badge_\(badge.badgeName)", content: content, trigger: trigger)
        Task { try? await center.add(request) }
    }

    // MARK: - Private

    private func scheduleMorningNotification(at time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Your Daily Walk"
        content.body = "Today's challenge is waiting for you."
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_challenge", content: content, trigger: trigger)
        Task { try? await center.add(request) }
    }

    private func scheduleEveningReminder(at time: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Don't Forget Your Walk"
        content.body = "You haven't completed today's challenge yet."
        content.sound = .default

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "evening_reminder", content: content, trigger: trigger)
        Task { try? await center.add(request) }
    }
}
