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

    /// Non-nil when the last change could not be persisted. Settings used to
    /// swallow the failure, leaving the toggle showing a value that was never
    /// written — the UI and the store disagreeing with no way to tell.
    private(set) var saveError: String?

    /// Fired after every persisted preference change. The composition root uses
    /// this to propagate the new preferences (translation to Daily Walk,
    /// notification reschedule) without Settings knowing about the other tabs.
    var onPreferencesChanged: (() -> Void)?

    private let persistence: PersistenceCoordinating
    private let profile: UserProfile

    /// The profile is injected, not fetched. Settings used to fetch-or-create its
    /// own, so a transient read error produced a second profile competing with
    /// the composition root's — two owners of state that must be unique.
    init(persistence: PersistenceCoordinating, profile: UserProfile) {
        self.persistence = persistence
        self.profile = profile
        self.translation = profile.preferredTranslation
        self.morningTime = profile.morningNotificationTime
        self.eveningTime = profile.eveningReminderTime
        self.morningEnabled = profile.morningNotificationsEnabled
        self.eveningEnabled = profile.eveningRemindersEnabled
        self.streakWarningsEnabled = profile.streakWarningsEnabled
        self.badgeNotificationsEnabled = profile.badgeNotificationsEnabled
        self.darkMode = profile.darkModePreference
    }

    func updateTranslation(_ newTranslation: BibleTranslation) {
        let previous = translation
        apply({
            self.translation = newTranslation
            self.profile.preferredTranslation = newTranslation
        }, revert: {
            self.translation = previous
            self.profile.preferredTranslation = previous
        })
    }

    func updateMorningTime(_ time: Date) {
        let previous = morningTime
        apply({
            self.morningTime = time
            self.profile.morningNotificationTime = time
        }, revert: {
            self.morningTime = previous
            self.profile.morningNotificationTime = previous
        })
    }

    func updateEveningTime(_ time: Date) {
        let previous = eveningTime
        apply({
            self.eveningTime = time
            self.profile.eveningReminderTime = time
        }, revert: {
            self.eveningTime = previous
            self.profile.eveningReminderTime = previous
        })
    }

    func toggleMorningNotifications(_ enabled: Bool) {
        let previous = morningEnabled
        apply({
            self.morningEnabled = enabled
            self.profile.morningNotificationsEnabled = enabled
        }, revert: {
            self.morningEnabled = previous
            self.profile.morningNotificationsEnabled = previous
        })
    }

    func toggleEveningReminders(_ enabled: Bool) {
        let previous = eveningEnabled
        apply({
            self.eveningEnabled = enabled
            self.profile.eveningRemindersEnabled = enabled
        }, revert: {
            self.eveningEnabled = previous
            self.profile.eveningRemindersEnabled = previous
        })
    }

    func toggleStreakWarnings(_ enabled: Bool) {
        let previous = streakWarningsEnabled
        apply({
            self.streakWarningsEnabled = enabled
            self.profile.streakWarningsEnabled = enabled
        }, revert: {
            self.streakWarningsEnabled = previous
            self.profile.streakWarningsEnabled = previous
        })
    }

    func toggleBadgeNotifications(_ enabled: Bool) {
        let previous = badgeNotificationsEnabled
        apply({
            self.badgeNotificationsEnabled = enabled
            self.profile.badgeNotificationsEnabled = enabled
        }, revert: {
            self.badgeNotificationsEnabled = previous
            self.profile.badgeNotificationsEnabled = previous
        })
    }

    func updateDarkMode(_ mode: DarkModePreference) {
        let previous = darkMode
        apply({
            self.darkMode = mode
            self.profile.darkModePreference = mode
        }, revert: {
            self.darkMode = previous
            self.profile.darkModePreference = previous
        })
    }

    func dismissSaveError() {
        saveError = nil
    }

    /// Applies a change and commits it. On failure the displayed value and the
    /// model are both put back, so what the user sees is always what is stored —
    /// and the change is never announced to the rest of the app.
    private func apply(_ mutate: () -> Void, revert: () -> Void) {
        mutate()
        do {
            try persistence.save()
            saveError = nil
            onPreferencesChanged?()
        } catch {
            revert()
            persistence.rollback()
            saveError = (error as? PersistenceError)?.message
                ?? PersistenceError.saveFailed(String(describing: error)).message
        }
    }
}
