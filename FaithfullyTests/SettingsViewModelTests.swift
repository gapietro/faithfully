import XCTest
import SwiftData
@testable import Faithfully

final class SettingsViewModelTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
    }

    func testInitLoadsAllPreferencesFromUserProfile() {
        let vm = SettingsViewModel(modelContext: context)
        // Default values
        XCTAssertEqual(vm.translation, .esv)
        XCTAssertTrue(vm.morningEnabled)
        XCTAssertTrue(vm.eveningEnabled)
        XCTAssertTrue(vm.streakWarningsEnabled)
        XCTAssertTrue(vm.badgeNotificationsEnabled)
        XCTAssertEqual(vm.darkMode, .system)
    }

    func testUpdateTranslationPersistsToSwiftData() throws {
        let vm = SettingsViewModel(modelContext: context)
        vm.updateTranslation(.niv)

        // Read back from SwiftData
        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(descriptor)
        XCTAssertEqual(profiles.first?.preferredTranslation, .niv)
    }

    func testUpdateTranslationImmediatelyReflectsInPublishedProperty() {
        let vm = SettingsViewModel(modelContext: context)
        XCTAssertEqual(vm.translation, .esv)
        vm.updateTranslation(.nkjv)
        XCTAssertEqual(vm.translation, .nkjv)
    }

    func testToggleNotificationsUpdatesPreferences() throws {
        let vm = SettingsViewModel(modelContext: context)
        vm.toggleMorningNotifications(false)
        vm.toggleEveningReminders(false)

        XCTAssertFalse(vm.morningEnabled)
        XCTAssertFalse(vm.eveningEnabled)

        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(descriptor)
        XCTAssertFalse(profiles.first?.morningNotificationsEnabled ?? true)
        XCTAssertFalse(profiles.first?.eveningRemindersEnabled ?? true)
    }

    func testDarkModeChangePersists() throws {
        let vm = SettingsViewModel(modelContext: context)
        vm.updateDarkMode(.dark)

        XCTAssertEqual(vm.darkMode, .dark)

        let descriptor = FetchDescriptor<UserProfile>()
        let profiles = try context.fetch(descriptor)
        XCTAssertEqual(profiles.first?.darkModePreference, .dark)
    }
}
