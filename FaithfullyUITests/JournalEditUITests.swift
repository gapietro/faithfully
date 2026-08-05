import XCTest

/// Mirrors `Constants.maxJournalLength` (2000). UI tests run out of process and
/// cannot import the app module, so the value is restated. `JournalTextTests`
/// guards the real one.
private let maxJournalLengthForUITests = 2000

final class JournalEditUITests: UITestCase {

    private let alpha = "seeded-journal-marker-alpha"

    /// The counter's accessibility value for a given length.
    ///
    /// The app builds it with SwiftUI string interpolation, which formats
    /// integers for the current locale — the counter reads "2,001 of 2,000",
    /// not "2001 of 2000". Formatting the expectation the same way keeps the
    /// test agreeing with the app rather than with one locale's separator.
    private func counterValue(forCharacters count: Int) -> String {
        "\(count.formatted()) of \(maxJournalLengthForUITests.formatted())"
    }

    private func journalEntry(containing marker: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
    }

    private func openEditorForFirstEntry() {
        openTab("Journey")
        let entry = journalEntry(containing: alpha)
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(app.textViews["journalEditor"].waitForExistence(timeout: 5),
                      "Tapping an entry must open the editor")
    }

    /// Opens yesterday's reflection through the calendar rather than the Journey
    /// timeline.
    ///
    /// The timeline renders a reflection in full, so a seeded 2,000-character
    /// one produces a row taller than the screen, whose centre — the point a tap
    /// is aimed at — cannot be scrolled into view. The day detail's Edit button
    /// stays a small, identified control however long the text above it is.
    private func openEditorForYesterdayFromCalendar() {
        openTab("Calendar")
        navigateToMonth(containing: targetDate(daysAgo: 1))
        let day = dayButton(dayNumber(daysAgo: 1))
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        day.tap()
        revealDayDetail()

        let edit = app.buttons["editJournalButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5),
                      "A completed day must offer to edit its reflection")
        edit.tap()
        XCTAssertTrue(app.textViews["journalEditor"].waitForExistence(timeout: 5),
                      "Tapping Edit reflection must open the editor")
    }

    func testEditingAnEntryPersistsAcrossRelaunch() {
        launch(.seeded)
        openEditorForFirstEntry()

        let editor = app.textViews["journalEditor"]
        editor.tap()
        editor.typeText(" — revised")
        app.buttons["saveJournalButton"].tap()

        let revised = journalEntry(containing: "revised")
        XCTAssertTrue(revised.waitForExistence(timeout: 10),
                      "The edited text must appear in the timeline")

        relaunchPreservingState()
        openTab("Journey")
        XCTAssertTrue(journalEntry(containing: "revised").waitForExistence(timeout: 10),
                      "The edit must survive a relaunch")
    }

    func testCancellingAnEditChangesNothing() {
        launch(.seeded)
        openEditorForFirstEntry()

        let editor = app.textViews["journalEditor"]
        editor.tap()
        editor.typeText(" DISCARD ME")
        app.buttons["cancelJournalEdit"].tap()

        XCTAssertTrue(journalEntry(containing: alpha).waitForExistence(timeout: 10))
        XCTAssertFalse(journalEntry(containing: "DISCARD ME").exists,
                       "Cancelling must not write anything")
    }

    func testDeletingAnEntryAsksFirstAndCanBeCancelled() {
        launch(.seeded)
        openTab("Journey")
        let entry = journalEntry(containing: alpha)
        XCTAssertTrue(entry.waitForExistence(timeout: 10))

        let total = intValue(of: "statTotalCompleted")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'deleteJournalEntry_'"))
            .firstMatch.tap()

        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5),
                      "Deleting must ask before destroying writing")
        app.buttons["Cancel"].tap()

        XCTAssertTrue(journalEntry(containing: alpha).waitForExistence(timeout: 5),
                      "Cancelling the dialog must keep the entry")
        XCTAssertEqual(intValue(of: "statTotalCompleted"), total)
    }

    func testDeletingAnEntryRemovesItButKeepsTheDayCompleted() {
        launch(.seeded)
        openTab("Journey")
        XCTAssertTrue(journalEntry(containing: alpha).waitForExistence(timeout: 10))

        let totalBefore = intValue(of: "statTotalCompleted")
        let streakBefore = intValue(of: "statCurrentStreak")

        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'deleteJournalEntry_'"))
            .firstMatch.tap()
        app.buttons["Delete"].tap()

        XCTAssertFalse(journalEntry(containing: alpha).waitForExistence(timeout: 5),
                       "The entry must leave the timeline")
        XCTAssertEqual(intValue(of: "statTotalCompleted"), totalBefore,
                       "Deleting a reflection must not change the completion total")
        XCTAssertEqual(intValue(of: "statCurrentStreak"), streakBefore,
                       "nor the streak")

        relaunchPreservingState()
        openTab("Journey")
        XCTAssertFalse(journalEntry(containing: alpha).waitForExistence(timeout: 5),
                       "The deletion must survive a relaunch")
    }

    func testAddingAReflectionFromTheCalendarToADayThatHadNone() {
        launch(.seeded)
        openTab("Calendar")

        // In the seeded scenario only the two most recent completions carry
        // journal text, so four days ago is completed with none. Navigate to
        // whichever month that falls in — deterministic on every day of the
        // year, rather than skipping at a month boundary.
        navigateToMonth(containing: targetDate(daysAgo: 4))
        let day = dayButton(dayNumber(daysAgo: 4))
        XCTAssertTrue(day.waitForExistence(timeout: 10))
        day.tap()
        revealDayDetail()

        let edit = app.buttons["editJournalButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5),
                      "A completed day with no reflection must offer to add one")
        XCTAssertEqual(edit.label, "Add reflection")
        edit.tap()

        let marker = "uitest-added-later"
        let editor = app.textViews["journalEditor"]
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        editor.typeText(marker)
        app.buttons["saveJournalButton"].tap()

        openTab("Journey")
        XCTAssertTrue(journalEntry(containing: marker).waitForExistence(timeout: 10),
                      "A reflection added from the calendar must appear in the journal")
    }

    func testOverLimitTextBlocksSaving() {
        launch(.atLimitJournal)
        openEditorForYesterdayFromCalendar()

        // Every step of the crossing is asserted rather than assumed. The
        // version that pasted 2,001 characters stepped over a paste that had
        // not happened — the edit menu never appeared — and then blamed the app
        // for the under-limit text it was left looking at (#102).
        let counter = app.staticTexts["journalCharacterCount"]
        XCTAssertTrue(counter.waitForExistence(timeout: 5))
        waitForValue(counter, equals: counterValue(forCharacters: maxJournalLengthForUITests),
                     "The editor must open holding exactly the limit")

        // Exactly at the limit is allowed. Without this half the test would
        // still pass against a Save button that is disabled unconditionally.
        let save = app.buttons["saveJournalButton"]
        wait(for: save, toBeEnabled: true,
             "Text exactly at the limit must be saveable")

        let editor = app.textViews["journalEditor"]
        editor.tap()
        editor.typeText("x")
        waitForValue(counter, equals: counterValue(forCharacters: maxJournalLengthForUITests + 1),
                     "Typing one more character must put the editor over the limit")
        wait(for: save, toBeEnabled: false,
             "Saving must be blocked while the text is over the limit")
    }
}
