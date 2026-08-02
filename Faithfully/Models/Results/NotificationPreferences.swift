import Foundation

/// The notification-relevant subset of a profile, as plain values.
///
/// `NotificationService` only ever reads these seven fields, but it used to take
/// the whole `UserProfile` — a SwiftData `@Model` class, which is neither
/// `Sendable` nor safe to touch off the actor that owns its context. In practice
/// the service snapshotted the values immediately and never let the model cross
/// a boundary, but nothing in the type said so, and under Swift 6 the compiler
/// is right not to take that on trust.
///
/// Taking the snapshot explicitly makes the boundary visible: everything past
/// this point is immutable value data that any task can safely hold.
struct NotificationPreferences: Sendable, Equatable {
    var morningEnabled: Bool
    var morningTime: Date
    var eveningEnabled: Bool
    var eveningTime: Date
    var streakWarningsEnabled: Bool
    var badgeNotificationsEnabled: Bool

    init(
        morningEnabled: Bool,
        morningTime: Date,
        eveningEnabled: Bool,
        eveningTime: Date,
        streakWarningsEnabled: Bool,
        badgeNotificationsEnabled: Bool
    ) {
        self.morningEnabled = morningEnabled
        self.morningTime = morningTime
        self.eveningEnabled = eveningEnabled
        self.eveningTime = eveningTime
        self.streakWarningsEnabled = streakWarningsEnabled
        self.badgeNotificationsEnabled = badgeNotificationsEnabled
    }

    /// Reads the model once, on whatever actor owns it, and hands back values.
    init(_ profile: UserProfile) {
        self.init(
            morningEnabled: profile.morningNotificationsEnabled,
            morningTime: profile.morningNotificationTime,
            eveningEnabled: profile.eveningRemindersEnabled,
            eveningTime: profile.eveningReminderTime,
            streakWarningsEnabled: profile.streakWarningsEnabled,
            badgeNotificationsEnabled: profile.badgeNotificationsEnabled
        )
    }
}
