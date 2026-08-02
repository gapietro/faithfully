import XCTest
import SwiftData
import SwiftUI
@testable import Faithfully

final class SettingsViewModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
    }

    /// The profile is now injected rather than fetched-or-created by Settings
    /// itself (CLEAN-004/CLEAN-012), so tests bootstrap it the way the
    /// composition root does: exactly once, and shared.
    private func makeViewModel(
        persistence: PersistenceCoordinating? = nil
    ) throws -> SettingsViewModel {
        let coordinator = persistence ?? PersistenceCoordinator(context: context)
        let profile = try coordinator.fetch(FetchDescriptor<UserProfile>()).first ?? {
            let created = UserProfile()
            coordinator.insert(created)
            try coordinator.save()
            return created
        }()
        return SettingsViewModel(persistence: coordinator, profile: profile)
    }

    func testInitLoadsAllPreferencesFromUserProfile() throws {
        let vm = try makeViewModel()
        // Default values
        XCTAssertEqual(vm.translation, .web)
        XCTAssertTrue(vm.morningEnabled)
        XCTAssertTrue(vm.eveningEnabled)
        XCTAssertTrue(vm.streakWarningsEnabled)
        XCTAssertTrue(vm.badgeNotificationsEnabled)
        XCTAssertEqual(vm.darkMode, .system)
    }

    func testUpdateTranslationPersistsToSwiftData() throws {
        let vm = try makeViewModel()
        vm.updateTranslation(.kjv)

        // Read back from SwiftData
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(descriptor)
        XCTAssertEqual(profiles.first?.preferredTranslation, .kjv)
    }

    func testUpdateTranslationImmediatelyReflectsInPublishedProperty() throws {
        let vm = try makeViewModel()
        XCTAssertEqual(vm.translation, .web)
        vm.updateTranslation(.kjv)
        XCTAssertEqual(vm.translation, .kjv)
    }

    func testToggleNotificationsUpdatesPreferences() throws {
        let vm = try makeViewModel()
        vm.toggleMorningNotifications(false)
        vm.toggleEveningReminders(false)

        XCTAssertFalse(vm.morningEnabled)
        XCTAssertFalse(vm.eveningEnabled)

        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(descriptor)
        XCTAssertFalse(profiles.first?.morningNotificationsEnabled ?? true)
        XCTAssertFalse(profiles.first?.eveningRemindersEnabled ?? true)
    }

    func testUpdateNotificationTimesPersistToSwiftData() throws {
        let vm = try makeViewModel()
        let calendar = Calendar.current
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 6, minute: 45)))
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 21, minute: 30)))

        vm.updateMorningTime(morning)
        vm.updateEveningTime(evening)

        XCTAssertEqual(vm.morningTime, morning)
        XCTAssertEqual(vm.eveningTime, evening)

        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<UserProfile>()).first)
        XCTAssertEqual(profile.morningNotificationTime, morning)
        XCTAssertEqual(profile.eveningReminderTime, evening)
    }

    func testEveryPreferenceMutationFiresOnPreferencesChanged() throws {
        let vm = try makeViewModel()
        var changeCount = 0
        vm.onPreferencesChanged = { changeCount += 1 }

        vm.updateTranslation(.kjv)
        vm.updateMorningTime(.now)
        vm.updateEveningTime(.now)
        vm.toggleMorningNotifications(false)
        vm.toggleEveningReminders(false)
        vm.toggleStreakWarnings(false)
        vm.toggleBadgeNotifications(false)
        vm.updateDarkMode(.dark)

        XCTAssertEqual(changeCount, 8,
                       "Every persisted preference change must notify the composition root")
    }

    func testDarkModePreferenceMapsToColorScheme() {
        XCTAssertNil(DarkModePreference.system.colorScheme)
        XCTAssertEqual(DarkModePreference.light.colorScheme, .light)
        XCTAssertEqual(DarkModePreference.dark.colorScheme, .dark)
    }

    func testDarkModeChangePersists() throws {
        let vm = try makeViewModel()
        vm.updateDarkMode(.dark)

        XCTAssertEqual(vm.darkMode, .dark)

        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(descriptor)
        XCTAssertEqual(profiles.first?.darkModePreference, .dark)
    }

    // MARK: - Single ownership and live constants (CLEAN-012)

    /// The composition root is the only component that creates a profile.
    /// Settings used to fetch-or-create its own, so a transient read error
    /// produced a second profile with a fresh enrollment date.
    func testSettingsDoesNotCreateItsOwnProfile() throws {
        let coordinator = PersistenceCoordinator(context: context)
        let profile = UserProfile()
        coordinator.insert(profile)
        try coordinator.save()

        _ = SettingsViewModel(persistence: coordinator, profile: profile)
        _ = SettingsViewModel(persistence: coordinator, profile: profile)

        XCTAssertEqual(try context.fetch(FetchDescriptor<UserProfile>()).count, 1,
                       "Building Settings must never mint another profile")
    }

    func testDefaultReminderTimesComeFromConstants() throws {
        let profile = UserProfile()
        let calendar = Calendar.current
        XCTAssertEqual(calendar.component(.hour, from: profile.morningNotificationTime),
                       Constants.defaultMorningHour)
        XCTAssertEqual(calendar.component(.hour, from: profile.eveningReminderTime),
                       Constants.defaultEveningHour)
    }
}
