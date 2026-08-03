import XCTest
import UIKit

/// Mirrors `Constants.maxJournalLength` (2000). UI tests run out of process and
/// cannot import the app module, so the value is restated. `JournalTextTests`
/// guards the real one.
private let maxJournalLengthForUITests = 2000

final class JournalEditUITests: UITestCase {

    private let alpha = "seeded-journal-marker-alpha"

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

    func testAddingAReflectionFromTheCalendarToADayThatHadNone() throws {
        try XCTSkipUnless(isInCurrentMonth(daysAgo: 4),
                          "Target day is in the previous month")
        launch(.seeded)
        openTab("Calendar")

        // In the seeded scenario only the two most recent completions carry
        // journal text, so four days ago is completed with none.
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
        launch(.seeded)
        openEditorForFirstEntry()

        let counter = app.staticTexts["journalCharacterCount"]
        XCTAssertTrue(counter.waitForExistence(timeout: 5))

        // Paste rather than type: 2,001 keystrokes takes minutes.
        let editor = app.textViews["journalEditor"]
        editor.tap()
        UIPasteboard.general.string = String(repeating: "a", count: maxJournalLengthForUITests + 1)
        editor.press(forDuration: 1.2)
        let paste = app.menuItems["Paste"]
        if paste.waitForExistence(timeout: 5) { paste.tap() }

        XCTAssertFalse(app.buttons["saveJournalButton"].isEnabled,
                       "Saving must be blocked while the text is over the limit")
    }
}
