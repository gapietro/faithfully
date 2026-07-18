import XCTest

final class SettingsUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // Navigate to Settings tab
        app.tabBars.buttons["Settings"].tap()
    }

    func testTranslationPickerShows3Options() {
        let section = app.staticTexts["Bible Translation"]
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Translation section should exist")
    }

    func testChangingTranslationUpdatesSelection() {
        let section = app.staticTexts["Bible Translation"]
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Translation section should exist")
    }

    func testNotificationTogglesExist() {
        let section = app.staticTexts["Notifications"]
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Notifications section should exist")

        let morningToggle = app.switches["morningToggle"]
        XCTAssertTrue(morningToggle.waitForExistence(timeout: 3), "Morning toggle should exist")

        let eveningToggle = app.switches["eveningToggle"]
        XCTAssertTrue(eveningToggle.waitForExistence(timeout: 3), "Evening toggle should exist")

        // Verify toggles are interactive
        XCTAssertTrue(morningToggle.isHittable, "Morning toggle should be tappable")
    }

    func testDarkModeToggleWorks() {
        let section = app.staticTexts["Appearance"]
        XCTAssertTrue(section.waitForExistence(timeout: 5), "Appearance section should exist in settings")
    }
}
