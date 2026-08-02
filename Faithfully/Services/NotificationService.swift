import Foundation
import UserNotifications

/// `Sendable` because the graph awaits `requestPermission()` from the main
/// actor, which sends the service across an isolation boundary. The concrete
/// implementation holds no mutable state — its ordering invariant lives inside a
/// lock-guarded chain (CLEAN-006) — so the guarantee is real rather than assumed.
protocol NotificationServiceProtocol: Sendable {
    func requestPermission() async -> Bool
    func scheduleAllNotifications(preferences: NotificationPreferences)
    func cancelTodayReminders()
    func scheduleStreakWarning(streak: Int, preferences: NotificationPreferences)
    func scheduleBadgeCelebration(named badgeName: String, preferences: NotificationPreferences)
}

/// `Sendable` because implementations are reached from the serialized operation
/// chain, which runs off the caller's context.
protocol NotificationCenterProtocol: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

/// `UNNotificationRequest` is immutable once constructed — its identifier,
/// content, and trigger are read-only, and the content it vends is a copy. The
/// UserNotifications module predates `Sendable` annotation, so the conformance
/// is stated here rather than blanketing the whole module with
/// `@preconcurrency`, which would also mask genuinely unsafe uses.
extension UNNotificationRequest: @retroactive @unchecked Sendable {}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}

/// Serial ordering for notification work.
///
/// The chain tail is guarded by a lock rather than left as bare mutable state.
/// Without it, two callers — a permission callback and a scene refresh, say —
/// could read the same predecessor, each build a successor, and have one
/// assignment overwrite the other. The overwritten operation drops out of the
/// chain entirely: a cancel could be lost so a cancelled reminder is
/// resurrected, and `waitForPendingOperations` could return before that work ran.
///
/// A lock rather than an actor because the ordering has to be established
/// *synchronously*, in call order, at the call site. Hopping into an actor to
/// link the chain would put the linking itself on an unordered task queue and
/// reintroduce exactly the race being fixed.
///
/// `@unchecked Sendable` is sound here: `tail` is the only mutable state and is
/// never read or written outside `lock`.
private final class OperationChain: @unchecked Sendable {
    private let lock = NSLock()
    private var tail: Task<Void, Never> = Task {}

    func enqueue(_ operation: @escaping @Sendable () async -> Void) {
        lock.withLock {
            let previous = tail
            tail = Task {
                await previous.value
                await operation()
            }
        }
    }

    /// Awaits everything enqueued up to this call. Work enqueued afterwards is
    /// deliberately not awaited — that is what "pending so far" means. The tail
    /// is read under the lock and awaited outside it, so draining never blocks
    /// another caller from enqueueing.
    func drain() async {
        let current = lock.withLock { tail }
        await current.value
    }
}

final class NotificationService: NotificationServiceProtocol, Sendable {
    let center: NotificationCenterProtocol

    /// All schedule/cancel work runs through this serial chain so a cancel
    /// issued after a schedule can never be overtaken by the schedule's async
    /// add — e.g. completing today right after a settings change must leave the
    /// evening reminder cancelled, not resurrected. `let`, so the service itself
    /// holds no mutable state; the ordering invariant lives inside the chain.
    private let operations = OperationChain()

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

    func scheduleAllNotifications(preferences: NotificationPreferences) {
        let morning = preferences.morningEnabled
            ? Self.makeDailyRequest(
                identifier: "morning_challenge",
                title: "Your Daily Walk",
                body: "Today's challenge is waiting for you.",
                time: preferences.morningTime
            )
            : nil
        let evening = preferences.eveningEnabled
            ? Self.makeDailyRequest(
                identifier: "evening_reminder",
                title: "Don't Forget Your Walk",
                body: "You haven't completed today's challenge yet.",
                time: preferences.eveningTime
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

    func scheduleStreakWarning(streak: Int, preferences: NotificationPreferences) {
        guard preferences.streakWarningsEnabled, streak >= 7 else { return }

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

    func scheduleBadgeCelebration(named badgeName: String, preferences: NotificationPreferences) {
        guard preferences.badgeNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Badge Earned!"
        content.body = "You earned the \(badgeName) badge!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "badge_\(badgeName)", content: content, trigger: trigger)
        enqueue { [center] in try? await center.add(request) }
    }

    /// Awaits every operation enqueued so far. Exposed for tests, which need
    /// the async adds to have landed before asserting on the mock center.
    func waitForPendingOperations() async {
        await operations.drain()
    }

    // MARK: - Private

    private func enqueue(_ operation: @escaping @Sendable () async -> Void) {
        operations.enqueue(operation)
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
