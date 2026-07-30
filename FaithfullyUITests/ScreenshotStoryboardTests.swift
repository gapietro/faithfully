import XCTest

/// Captures App Store storyboard shots @ device resolution to FAITHFULLY_SCREENSHOT_DIR
/// (default `/tmp/faithfully-screenshots-6.9`).
final class ScreenshotStoryboardTests: XCTestCase {
    private var outDir: URL {
        if let env = ProcessInfo.processInfo.environment["FAITHFULLY_SCREENSHOT_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env, isDirectory: true)
        }
        return URL(fileURLWithPath: "/tmp/faithfully-screenshots-6.9", isDirectory: true)
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    }

    func testCaptureStoryboard() throws {
        // ===== Pass A: onboarding only =====
        let appA = XCUIApplication()
        appA.launchArguments = ["-hasCompletedOnboarding", "NO"]
        appA.launch()
        XCTAssertTrue(appA.staticTexts["welcomeTitle"].waitForExistence(timeout: 10))
        sleep(1)
        try saveShot(name: "05_onboarding")
        appA.terminate()

        // ===== Pass B: main app (skip onboarding) =====
        let app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // Wait for tab bar — primary proof we're past onboarding
        let dailyTab = app.tabBars.buttons["Daily Walk"]
        XCTAssertTrue(dailyTab.waitForExistence(timeout: 12), "Main tabs should appear")
        dailyTab.tap()
        sleep(1)

        // Dismiss any leftover system alerts
        allowNotificationsIfPresent()
        sleep(1)

        // Shot 1 — Daily Walk hero
        waitForAny([
            app.staticTexts["challengeTitle"],
            app.staticTexts["scriptureText"],
            app.buttons["iDidItButton"],
            app.staticTexts["completedLabel"],
        ], timeout: 10)
        sleep(1)
        try saveShot(name: "01_daily_walk")

        // Shot 2 — Completion sheet
        let iDidIt = app.buttons["iDidItButton"]
        if iDidIt.waitForExistence(timeout: 3), iDidIt.isHittable {
            iDidIt.tap()
            let journal = app.textViews["journalEditor"]
            XCTAssertTrue(journal.waitForExistence(timeout: 6), "Completion sheet journal")
            journal.tap()
            journal.typeText("Grateful for today's walk.")
            sleep(1)
            try saveShot(name: "02_completion")
            let complete = app.buttons["completeButton"]
            if complete.waitForExistence(timeout: 3) {
                complete.tap()
            }
            sleep(1)
            // Dismiss celebration overlay if present
            if app.otherElements["celebration"].waitForExistence(timeout: 2)
                || app.images["celebrationIcon"].waitForExistence(timeout: 1) {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92)).tap()
                sleep(1)
            }
        } else {
            // Already completed — capture completed Daily Walk as fallback
            try saveShot(name: "02_completion")
        }

        // Shot 3 — Calendar
        tapTab(app, "Calendar")
        waitForAny([
            app.otherElements["monthGrid"],
            app.staticTexts["monthTitle"],
            app.buttons["previousMonth"],
        ], timeout: 8)
        sleep(1)
        try saveShot(name: "03_calendar")

        // Shot 4 — Journey
        tapTab(app, "Journey")
        waitForAny([
            app.otherElements["statsSection"],
            app.staticTexts["Completed"],
            app.staticTexts["Streak"],
        ], timeout: 8)
        sleep(1)
        try saveShot(name: "04_journey")

        // Shot 6 — Settings
        tapTab(app, "Settings")
        waitForAny([
            app.buttons["translationPicker"],
            app.switches["morningToggle"],
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Privacy")).firstMatch,
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "Appearance")).firstMatch,
        ], timeout: 8)
        sleep(1)
        try saveShot(name: "06_settings")

        // Integrity
        for name in [
            "01_daily_walk.png", "02_completion.png", "03_calendar.png",
            "04_journey.png", "05_onboarding.png", "06_settings.png",
        ] {
            let url = outDir.appendingPathComponent(name)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "Missing \(name)")
            let size = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber
            XCTAssertGreaterThan(size?.intValue ?? 0, 40_000, "\(name) too small")
        }
    }

    private func saveShot(name: String) throws {
        let shot = XCUIScreen.main.screenshot()
        try shot.pngRepresentation.write(to: outDir.appendingPathComponent("\(name).png"), options: .atomic)
        let att = XCTAttachment(screenshot: shot)
        att.name = name
        att.lifetime = .keepAlways
        add(att)
    }

    private func tapTab(_ app: XCUIApplication, _ label: String) {
        let tab = app.tabBars.buttons[label]
        XCTAssertTrue(tab.waitForExistence(timeout: 6), "Tab \(label)")
        tab.tap()
    }

    private func waitForAny(_ elements: [XCUIElement], timeout: TimeInterval) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if elements.contains(where: { $0.exists }) { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        // Soft: still proceed to screenshot whatever is on screen (store art needs pixels)
        XCTContext.runActivity(named: "waitForAny soft miss") { _ in }
    }

    private func allowNotificationsIfPresent() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for title in ["Allow", "Allow While Using App", "OK"] {
            let b = springboard.buttons[title]
            if b.waitForExistence(timeout: 1.5) {
                b.tap()
                return
            }
        }
    }
}
