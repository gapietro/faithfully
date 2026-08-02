import XCTest

final class SettingsUITests: UITestCase {

    /// Was: assert the "Bible Translation" heading exists — which passed even if
    /// the picker offered nothing at all.
    func testTranslationPickerOffersEveryTranslation() {
        launch(.seeded)
        openTab("Settings")

        let picker = app.buttons["translationPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10), "The translation picker must exist")
        picker.tap()

        // The picker lists the short names the UI actually renders.
        for translation in ["WEB", "KJV"] {
            XCTAssertTrue(
                app.buttons[translation].waitForExistence(timeout: 5),
                "\(translation) must be offered as a choice"
            )
        }
    }

    /// Was an exact duplicate of the test above, asserting only the section
    /// heading — it never changed a translation and never checked a selection.
    ///
    /// Asserts the observable consequence rather than the control's own state:
    /// choosing a translation must change the scripture the user reads. A picker
    /// that stores the value but never reaches the card would still pass a
    /// selection-only check.
    func testChangingTranslationChangesTheScriptureShownAndPersists() {
        launch(.seeded)
        openTab("Daily Walk")
        let scripture = app.staticTexts["scriptureText"]
        XCTAssertTrue(scripture.waitForExistence(timeout: 10), "The card must show scripture")
        let originalScripture = scripture.label
        XCTAssertFalse(originalScripture.isEmpty)

        openTab("Settings")
        let picker = app.buttons["translationPicker"]
        XCTAssertTrue(picker.waitForExistence(timeout: 10))
        picker.tap()
        app.buttons["KJV"].tap()

        openTab("Daily Walk")
        XCTAssertTrue(scripture.waitForExistence(timeout: 10))
        XCTAssertNotEqual(scripture.label, originalScripture,
                          "Switching translation must change the scripture text on the card")
        let kjvScripture = scripture.label

        relaunchPreservingState()
        openTab("Daily Walk")
        XCTAssertTrue(scripture.waitForExistence(timeout: 10))
        XCTAssertEqual(scripture.label, kjvScripture,
                       "The chosen translation must survive a relaunch")
    }

    func testTogglingANotificationPreferencePersists() {
        launch(.seeded)
        openTab("Settings")

        let morning = app.switches["morningToggle"]
        XCTAssertTrue(morning.waitForExistence(timeout: 10))
        let original = morning.value as? String
        XCTAssertEqual(original, "1", "Morning reminders default to on")

        morning.switches.firstMatch.tap()
        XCTAssertEqual(morning.value as? String, "0", "Tapping must actually flip the switch")

        relaunchPreservingState()
        openTab("Settings")
        assertValue(app.switches["morningToggle"], equals: "0",
                    "A preference change must survive a relaunch")
    }

    func testDisablingMorningRemindersDisablesItsTimePicker() {
        launch(.seeded)
        openTab("Settings")

        let morning = app.switches["morningToggle"]
        XCTAssertTrue(morning.waitForExistence(timeout: 10))
        let timePicker = app.datePickers["morningTimePicker"]
        XCTAssertTrue(timePicker.waitForExistence(timeout: 5))
        XCTAssertTrue(timePicker.isEnabled, "The time picker is usable while reminders are on")

        morning.switches.firstMatch.tap()
        XCTAssertFalse(timePicker.isEnabled,
                       "Turning reminders off must disable the time that has no effect")
    }

    /// Was: assert an "Appearance" heading exists. It never toggled anything.
    func testChangingAppearanceUpdatesTheSelection() {
        launch(.seeded)
        openTab("Settings")

        let darkMode = app.buttons["darkModePicker"]
        XCTAssertTrue(darkMode.waitForExistence(timeout: 10), "The appearance picker must exist")
        XCTAssertTrue(darkMode.staticTexts["System"].exists, "Appearance defaults to System")

        darkMode.tap()
        app.buttons["Dark"].tap()

        XCTAssertTrue(darkMode.staticTexts["Dark"].waitForExistence(timeout: 5),
                      "The picker must show the chosen appearance")
        XCTAssertFalse(darkMode.staticTexts["System"].exists)

        relaunchPreservingState()
        openTab("Settings")
        let reopened = app.buttons["darkModePicker"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 10))
        XCTAssertTrue(reopened.staticTexts["Dark"].exists,
                      "The appearance choice must survive a relaunch")
    }

    func testNoSaveErrorIsShownOnAHealthyStore() {
        launch(.seeded)
        openTab("Settings")

        XCTAssertTrue(app.switches["morningToggle"].waitForExistence(timeout: 10))
        app.switches["morningToggle"].switches.firstMatch.tap()

        XCTAssertFalse(app.staticTexts["settingsSaveError"].exists,
                       "A successful save must not surface an error")
    }
}
