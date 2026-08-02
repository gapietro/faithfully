import XCTest

final class HomeScreenUITests: UITestCase {

    func testChallengeCardDisplaysOnLaunch() {
        launch(.seeded)
        openTab("Daily Walk")

        let title = app.staticTexts["challengeTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10), "Challenge card should display on launch")
        XCTAssertFalse(
            (title.label).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "The card must show real challenge text, not an empty label"
        )
    }

    /// Was `XCTAssertTrue(completed.exists || true)` — unconditionally true. With
    /// a seeded scenario the state is known, so the assertion can be absolute.
    func testTodayIsCompletableWhenNotYetDone() {
        launch(.seeded)
        openTab("Daily Walk")

        let button = app.buttons["iDidItButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10),
                      "An incomplete today must offer the completion button")
        XCTAssertTrue(button.isHittable)
        XCTAssertFalse(app.staticTexts["completedLabel"].exists,
                       "An incomplete day must not show the completed label")
    }

    func testAlreadyCompletedTodayShowsCompletedAndHidesTheButton() {
        launch(.completedToday)
        openTab("Daily Walk")

        XCTAssertTrue(app.staticTexts["completedLabel"].waitForExistence(timeout: 10),
                      "A completed today must say so")
        XCTAssertFalse(app.buttons["iDidItButton"].exists,
                       "A completed day must not still offer the completion button")
    }

    func testCompletingTodayPersistsAcrossRelaunch() {
        launch(.seeded)
        openTab("Daily Walk")

        let button = app.buttons["iDidItButton"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        button.tap()

        let complete = app.buttons["completeButton"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5), "The reflection sheet must appear")
        complete.tap()

        XCTAssertTrue(app.staticTexts["completedLabel"].waitForExistence(timeout: 10),
                      "Completing must flip the day to completed")

        // In memory is not enough — it has to still be true after a relaunch.
        relaunchPreservingState()
        openTab("Daily Walk")
        XCTAssertTrue(app.staticTexts["completedLabel"].waitForExistence(timeout: 10),
                      "The completion must survive a relaunch")
        XCTAssertFalse(app.buttons["iDidItButton"].exists)
    }

    func testCompletingRaisesTheStreakCount() {
        launch(.seeded)
        openTab("Journey")
        let streakBefore = intValue(of: "statCurrentStreak")
        XCTAssertNotNil(streakBefore, "Streak must be exposed as a number")

        openTab("Daily Walk")
        app.buttons["iDidItButton"].tap()
        app.buttons["completeButton"].tap()
        XCTAssertTrue(app.staticTexts["completedLabel"].waitForExistence(timeout: 10))

        openTab("Journey")
        let streakAfter = intValue(of: "statCurrentStreak")
        XCTAssertEqual(streakAfter, (streakBefore ?? 0) + 1,
                       "Completing today must extend the streak by exactly one")
    }

    // MARK: - Journal editor (CLEAN-003)

    func testJournalCounterReflectsWhatWasTyped() {
        launch(.seeded)
        openTab("Daily Walk")
        app.buttons["iDidItButton"].tap()

        let counter = app.staticTexts["journalCharacterCount"]
        XCTAssertTrue(counter.waitForExistence(timeout: 5),
                      "The character limit must be visible before the user commits to it")
        XCTAssertEqual(counter.label, "2000 characters remaining",
                       "An empty editor must announce the full allowance")

        let editor = app.textViews["journalEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText("Grateful today.")

        XCTAssertEqual(counter.label, "1985 characters remaining",
                       "The counter must track the text, not announce a fixed string")
    }

    func testJournalTextIsSavedAndVisibleInTheJournal() {
        launch(.seeded)
        openTab("Daily Walk")
        app.buttons["iDidItButton"].tap()

        let marker = "uitest-journal-roundtrip"
        let editor = app.textViews["journalEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(marker)
        app.buttons["completeButton"].tap()

        XCTAssertTrue(app.staticTexts["completedLabel"].waitForExistence(timeout: 10))

        openTab("Journey")
        let saved = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", marker)
        ).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 10),
                      "A written reflection must appear in the journal, whole")
    }

    func testStreakCounterShowsTheSeededStreak() {
        launch(.seeded)
        openTab("Daily Walk")

        let streak = app.staticTexts["streakCounter"]
        XCTAssertTrue(streak.waitForExistence(timeout: 10))
        XCTAssertTrue(streak.label.contains("40"),
                      "40 seeded consecutive days must read as a 40 day streak, got '\(streak.label)'")
    }

    func testYesterdaysChallengeIsShownAndDiffersFromTodays() {
        launch(.seeded)
        openTab("Daily Walk")

        let today = app.staticTexts["challengeTitle"]
        XCTAssertTrue(today.waitForExistence(timeout: 10))

        let yesterday = app.staticTexts["yesterdayChallengeTitle"]
        XCTAssertTrue(yesterday.waitForExistence(timeout: 5), "Yesterday's challenge must be present")
        XCTAssertTrue(yesterday.label.hasPrefix("Yesterday:"))
        XCTAssertNotEqual(yesterday.label, "Yesterday: \(today.label)",
                          "Yesterday must show its own challenge, not a copy of today's")
    }
}
