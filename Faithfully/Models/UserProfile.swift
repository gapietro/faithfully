import Foundation
import SwiftData

@Model
final class UserProfile {
    var id: UUID
    var displayName: String
    var startDate: Date
    var preferredTranslation: BibleTranslation
    var morningNotificationTime: Date
    var eveningReminderTime: Date
    var morningNotificationsEnabled: Bool
    var eveningRemindersEnabled: Bool
    var streakWarningsEnabled: Bool
    var badgeNotificationsEnabled: Bool
    var darkModePreference: DarkModePreference

    init(
        id: UUID = UUID(),
        displayName: String = "",
        startDate: Date = .now,
        preferredTranslation: BibleTranslation = .esv,
        morningNotificationTime: Date = Calendar.current.date(from: DateComponents(hour: 7, minute: 0)) ?? .now,
        eveningReminderTime: Date = Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? .now,
        morningNotificationsEnabled: Bool = true,
        eveningRemindersEnabled: Bool = true,
        streakWarningsEnabled: Bool = true,
        badgeNotificationsEnabled: Bool = true,
        darkModePreference: DarkModePreference = .system
    ) {
        self.id = id
        self.displayName = displayName
        self.startDate = startDate
        self.preferredTranslation = preferredTranslation
        self.morningNotificationTime = morningNotificationTime
        self.eveningReminderTime = eveningReminderTime
        self.morningNotificationsEnabled = morningNotificationsEnabled
        self.eveningRemindersEnabled = eveningRemindersEnabled
        self.streakWarningsEnabled = streakWarningsEnabled
        self.badgeNotificationsEnabled = badgeNotificationsEnabled
        self.darkModePreference = darkModePreference
    }
}
