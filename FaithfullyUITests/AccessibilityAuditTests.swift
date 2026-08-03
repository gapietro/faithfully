import XCTest

/// Runs Apple's own accessibility audit over every screen.
///
/// The audit catches what a human pass usually catches late and unevenly:
/// unlabelled controls, hit targets under 44pt, text that clips at large Dynamic
/// Type sizes, insufficient contrast, and elements that trap or confuse
/// VoiceOver. Running it in CI means a regression is caught on the pull request
/// that introduces it rather than on someone's device.
///
/// This does **not** replace a device pass with VoiceOver actually switched on
/// (#55). It replaces the part of that pass a machine can do reliably, so the
/// human time goes to the part it cannot: whether the app makes *sense* when
/// read aloud.
final class AccessibilityAuditTests: UITestCase {

    override func setUp() {
        super.setUp()
        // Report every issue on a screen, not just the first: fixing them one
        // build at a time is how an accessibility pass takes a week.
        continueAfterFailure = true
    }

    private func audit(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try app.performAccessibilityAudit { issue in
            // Two narrow exclusions, both about what the audit can see rather
            // than about what the app does. There is no ignore list of specific
            // elements or issue types — that is how an accessibility gate
            // quietly stops being one.
            //
            // 1. Issues the audit cannot attribute to an element. These come
            //    from system chrome and there is nothing here to change.
            guard let element = issue.element else { return true }

            // 2. Elements sitting underneath the translucent tab bar. Content
            //    scrolling under the bar is the standard iOS behaviour and the
            //    user scrolls to reach it; the audit measures it where it
            //    happens to rest. Judging it there would mean either abandoning
            //    scroll-under-bar layout or permanently failing the gate.
            let tabBar = app.tabBars.firstMatch
            if tabBar.exists && element.frame.intersects(tabBar.frame) { return true }

            XCTFail(
                "\(issue.auditType): \(issue.compactDescription) | element: "
                + "\(issue.element?.debugDescription ?? "nil")",
                file: file, line: line
            )
            return true
        }
    }

    func testDailyWalkIsAccessible() throws {
        launch(.seeded)
        openTab("Daily Walk")
        XCTAssertTrue(app.staticTexts["challengeTitle"].waitForExistence(timeout: 10))
        try audit(app)
    }

    func testCompletionSheetIsAccessible() throws {
        launch(.seeded)
        openTab("Daily Walk")
        app.buttons["iDidItButton"].tap()
        XCTAssertTrue(app.textViews["journalEditor"].waitForExistence(timeout: 5))
        try audit(app)
    }

    func testCalendarIsAccessible() throws {
        launch(.seeded)
        openTab("Calendar")
        XCTAssertTrue(dayButton(1).waitForExistence(timeout: 10))
        try audit(app)
    }

    func testCalendarDayDetailIsAccessible() throws {
        launch(.graceAvailable)
        openTab("Calendar")
        XCTAssertTrue(dayButton(1).waitForExistence(timeout: 10))
        dayButton(1).tap()
        revealDayDetail()
        try audit(app)
    }

    func testJourneyIsAccessible() throws {
        launch(.seeded)
        openTab("Journey")
        XCTAssertTrue(app.staticTexts["statTotalCompleted"].waitForExistence(timeout: 10))
        try audit(app)
    }

    func testSettingsIsAccessible() throws {
        launch(.seeded)
        openTab("Settings")
        XCTAssertTrue(app.buttons["translationPicker"].waitForExistence(timeout: 10))
        try audit(app)
    }

    func testOnboardingIsAccessible() throws {
        launch(.fresh, onboardingComplete: false)
        XCTAssertTrue(app.staticTexts["welcomeTitle"].waitForExistence(timeout: 10))
        try audit(app)
    }

    /// A first-day user's calendar is mostly pre-enrollment days, which are
    /// styled differently from every other state — the case most likely to fall
    /// below the contrast threshold.
    func testFreshInstallCalendarIsAccessible() throws {
        launch(.fresh)
        openTab("Calendar")
        XCTAssertTrue(dayButton(1).waitForExistence(timeout: 10))
        try audit(app)
    }

    func testJournalEditSheetIsAccessible() throws {
        launch(.seeded)
        openTab("Journey")
        let entry = app.staticTexts
            .containing(NSPredicate(format: "label CONTAINS %@", "seeded-journal-marker-alpha"))
            .firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.textViews["journalEditor"].waitForExistence(timeout: 5))
        try audit(app)
    }
}
