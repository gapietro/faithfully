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

    /// Pinned so the audit renders the same screen on every run.
    ///
    /// The daily challenge rotates, so on an unpinned clock the card's text
    /// length — and with it the vertical position of every control below it —
    /// changes from one day to the next. The audit judges *rendered* pixels, so
    /// that made a green run evidence about the day it ran on and nothing more:
    /// the same commit passed locally and failed on a runner that had crossed
    /// midnight UTC (#89). Noon UTC so the civil day is the same in every
    /// timezone a runner is plausibly set to.
    static let auditDate = ISO8601DateFormatter().date(from: "2026-03-15T12:00:00Z")!

    override func setUp() {
        super.setUp()
        fixedDate = Self.auditDate
        // Report every issue on a screen, not just the first: fixing them one
        // build at a time is how an accessibility pass takes a week.
        continueAfterFailure = true
    }

    /// The band iOS 26 renders its scroll-edge effect into, or nil on a system
    /// that has no such effect.
    ///
    /// Taken from the system's own element rather than computed from the tab bar
    /// with a constant, so it tracks whatever height the OS actually uses. The
    /// effect image is deliberately oversized and hangs off both edges of the
    /// screen, so it is clipped to the window before being used as a region.
    ///
    /// `AdditionalDimmingOverlay` is a system identifier and could be renamed by
    /// a future iOS. That fails in the safe direction: the exclusion narrows,
    /// the audit gets noisier rather than quieter, and
    /// `testDailyWalkIsAccessibleAtLargerTextSize` asserts the band was found,
    /// so the rename is reported by a test that names this dependency instead of
    /// silently widening what the gate ignores.
    private func scrollEdgeEffectFrame(in app: XCUIApplication) -> CGRect? {
        let overlay = app.descendants(matching: .image)
            .matching(identifier: "AdditionalDimmingOverlay")
            .firstMatch
        guard overlay.exists else { return nil }
        let clipped = overlay.frame.intersection(app.windows.firstMatch.frame)
        return clipped.isNull || clipped.isEmpty ? nil : clipped
    }

    /// Text and controls resting inside `band` but clear of the tab bar — the
    /// gap the old exclusion left open.
    private func elementsResting(in band: CGRect, above tabBar: CGRect) -> [XCUIElement] {
        let candidates = app.staticTexts.allElementsBoundByAccessibilityElement
            + app.buttons.allElementsBoundByAccessibilityElement
        return candidates.filter { element in
            let frame = element.frame
            guard !frame.isEmpty else { return false }
            return frame.intersects(band) && !frame.intersects(tabBar)
        }
    }

    private func audit(
        _ app: XCUIApplication,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        // Resolved once, before the audit runs, rather than per issue: these are
        // queries against the element tree and the audit reports every issue on
        // the screen.
        let tabBarFrame = app.tabBars.firstMatch.exists ? app.tabBars.firstMatch.frame : .null
        let effectBand = scrollEdgeEffectFrame(in: app) ?? .null

        try app.performAccessibilityAudit { issue in
            // Three narrow exclusions, all about what the audit can *see*
            // rather than about what the app does. There is no ignore list of
            // specific elements — that is how an accessibility gate quietly
            // stops being one.
            //
            // 1. Issues the audit cannot attribute to an element. These come
            //    from system chrome and there is nothing here to change.
            guard let element = issue.element else { return true }
            let frame = element.frame

            // 2. Elements sitting underneath the translucent tab bar. Content
            //    scrolling under the bar is the standard iOS behaviour and the
            //    user scrolls to reach it; the audit measures it where it
            //    happens to rest. Judging it there would mean either abandoning
            //    scroll-under-bar layout or permanently failing the gate.
            //    Occluded elements cannot be judged on anything, so this one
            //    covers every issue type.
            if !tabBarFrame.isNull && frame.intersects(tabBarFrame) { return true }

            // 3. *Contrast only*, for elements resting in the iOS 26 scroll-edge
            //    effect band — which extends roughly 65pt above the tab bar, so
            //    exclusion 2 does not reach it.
            //
            //    The audit reports "Contrast failed" for anything overlapping
            //    that band regardless of the pixels actually rendered. Measured
            //    on the captured screen: the navy "I Did It" button reads
            //    11.55:1 and the card's reflection text 12.67–13.78:1, against a
            //    4.5:1 threshold. Suppressing the effect leaves the element at
            //    the identical frame and the issue disappears, so the effect —
            //    not the colour — is what is being reported (#89).
            //
            //    Deliberately narrower than exclusion 2: the band distorts
            //    colour sampling only. Hit-target size, clipped text, missing
            //    labels and VoiceOver traps are all still judged here.
            if issue.auditType == .contrast, !effectBand.isNull, frame.intersects(effectBand) {
                return true
            }

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

    /// The case that broke the gate (#89).
    ///
    /// iOS 26 draws a scroll-edge dimming effect in a band well above the tab
    /// bar, and the audit reports "Contrast failed" for anything overlapping it
    /// — including a navy button with white text measuring 11.55:1 in the
    /// captured pixels. Whether a control landed in that band depended on the
    /// day's challenge text, so the failure looked environmental.
    ///
    /// A larger Dynamic Type size pushes content down into the band on the
    /// pinned date, reproducing the runner's geometry deliberately rather than
    /// waiting for the calendar to reproduce it by accident. It also buys real
    /// coverage: large text is where a layout is most likely to break.
    ///
    /// On the runner it was `iDidItButton` that landed there; here it is the
    /// card's reflection question. The precondition below asserts the
    /// *condition* rather than either element, because which control lands in
    /// the band is the incidental detail that made this look environmental.
    func testDailyWalkIsAccessibleAtLargerTextSize() throws {
        extraLaunchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryXL"]
        launch(.seeded)
        openTab("Daily Walk")
        XCTAssertTrue(app.staticTexts["challengeTitle"].waitForExistence(timeout: 10))

        // Guards the reproduction itself. Which control lands in the band is
        // incidental — that is precisely what made this look environmental — so
        // the precondition is the condition that triggers the bug rather than
        // the name of whichever element happened to trigger it on the runner.
        XCTAssertTrue(app.buttons["iDidItButton"].waitForExistence(timeout: 5))
        let band = scrollEdgeEffectFrame(in: app)
        XCTAssertNotNil(band, "iOS 26 renders a scroll-edge effect; this test needs it present")
        if let band {
            XCTAssertFalse(elementsResting(in: band, above: app.tabBars.firstMatch.frame).isEmpty,
                           "Precondition: some content must rest in the scroll-edge band and "
                           + "above the tab bar, or this test is not exercising #89 (band \(band))")
        }

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
