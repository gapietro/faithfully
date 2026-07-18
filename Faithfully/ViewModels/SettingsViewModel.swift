import Foundation
import SwiftData
import Observation

@Observable
final class SettingsViewModel {
    var translation: BibleTranslation
    var morningTime: Date
    var eveningTime: Date
    var morningEnabled: Bool
    var eveningEnabled: Bool
    var streakWarningsEnabled: Bool
    var badgeNotificationsEnabled: Bool
    var darkMode: DarkModePreference

    private let modelContext: ModelContext
    private var profile: UserProfile

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        // Load or create profile
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        let existingProfile = profiles.first ?? UserProfile()

        if profiles.isEmpty {
            modelContext.insert(existingProfile)
            try? modelContext.save()
        }

        self.profile = existingProfile
        self.translation = existingProfile.preferredTranslation
        self.morningTime = existingProfile.morningNotificationTime
        self.eveningTime = existingProfile.eveningReminderTime
        self.morningEnabled = existingProfile.morningNotificationsEnabled
        self.eveningEnabled = existingProfile.eveningRemindersEnabled
        self.streakWarningsEnabled = existingProfile.streakWarningsEnabled
        self.badgeNotificationsEnabled = existingProfile.badgeNotificationsEnabled
        self.darkMode = existingProfile.darkModePreference
    }

    func updateTranslation(_ newTranslation: BibleTranslation) {
        translation = newTranslation
        profile.preferredTranslation = newTranslation
        try? modelContext.save()
    }

    func toggleMorningNotifications(_ enabled: Bool) {
        morningEnabled = enabled
        profile.morningNotificationsEnabled = enabled
        try? modelContext.save()
    }

    func toggleEveningReminders(_ enabled: Bool) {
        eveningEnabled = enabled
        profile.eveningRemindersEnabled = enabled
        try? modelContext.save()
    }

    func toggleStreakWarnings(_ enabled: Bool) {
        streakWarningsEnabled = enabled
        profile.streakWarningsEnabled = enabled
        try? modelContext.save()
    }

    func toggleBadgeNotifications(_ enabled: Bool) {
        badgeNotificationsEnabled = enabled
        profile.badgeNotificationsEnabled = enabled
        try? modelContext.save()
    }

    func updateDarkMode(_ mode: DarkModePreference) {
        darkMode = mode
        profile.darkModePreference = mode
        try? modelContext.save()
    }
}
