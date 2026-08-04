import XCTest

final class JourneyUITests: UITestCase {

    func testStatsShowTheSeededTotals() {
        launch(.seeded)
        openTab("Journey")

        assertStat("statTotalCompleted", equals: 40, "40 seeded completions must be reported as 40")
        assertStat("statCurrentStreak", equals: 40, "40 consecutive seeded days must read as a 40 day streak")
    }

    func testFreshInstallShowsZeroedStats() {
        launch(.fresh)
        openTab("Journey")

        assertStat("statTotalCompleted", equals: 0)
        assertStat("statCurrentStreak", equals: 0)
    }

    /// Was: assert a "5K" label exists — which passed whether or not the badge
    /// was earned, and whether or not earned badges looked any different.
    func testEarnedBadgesAreDistinguishableFromUnearnedOnes() {
        launch(.seeded)
        openTab("Journey")

        // 40 completions clears the 5K threshold (31) but not 10K (90).
        assertValue(element("badge_journey_5k"), equals: "Earned",
                    "5K must be earned at 40 completions")

        let tenK = element("badge_journey_10k")
        XCTAssertTrue(tenK.waitForExistence(timeout: 10))
        XCTAssertEqual(tenK.value as? String, "Not earned, 40 of 90",
                       "An unearned badge must report its real progress")
    }

    func testNoBadgesAreEarnedOnAFreshInstall() {
        launch(.fresh)
        openTab("Journey")

        assertValue(element("badge_journey_5k"), equals: "Not earned, 0 of 31",
                    "A fresh install must not show earned badges")
    }

    /// An unearned badge cell contains a progress bar, so it surfaces as a
    /// progress indicator; an earned one has nothing left to progress toward and
    /// surfaces as plain text. Asserting the element kind catches the bar being
    /// removed, which a value-only check would not.
    func testProgressBarsAppearOnlyForUnearnedBadges() {
        launch(.seeded)
        openTab("Journey")

        let unearned = app.progressIndicators.matching(identifier: "badge_journey_10k").firstMatch
        XCTAssertTrue(unearned.waitForExistence(timeout: 10),
                      "An unearned badge must show its progress")

        XCTAssertFalse(app.progressIndicators.matching(identifier: "badge_journey_5k").firstMatch.exists,
                       "An earned badge has nothing left to progress toward")
        XCTAssertTrue(element("badge_journey_5k").waitForExistence(timeout: 5),
                      "but the earned badge itself must still be present")
    }

    func testJournalEntriesDisplayTheirText() {
        launch(.seeded)
        openTab("Journey")

        let entry = journalEntry(containing: "seeded-journal-marker-alpha")
        XCTAssertTrue(entry.waitForExistence(timeout: 10),
                      "A completion with journal text must appear in the journal")
    }

    /// NSPredicate is not Sendable, so under Swift 6 it cannot be held in a
    /// local and reused across `await`-adjacent calls. Building it per lookup
    /// costs nothing and keeps the tests in the language mode the app ships in.
    private func journalEntry(containing marker: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", marker)).firstMatch
    }

    /// Was: assert the "Completed" stat exists. It never touched the search field.
    func testSearchFieldFiltersEntries() {
        launch(.seeded)
        openTab("Journey")

        XCTAssertTrue(journalEntry(containing: "seeded-journal-marker-alpha")
            .waitForExistence(timeout: 10))
        XCTAssertTrue(journalEntry(containing: "seeded-journal-marker-beta").exists,
                      "Precondition: both seeded entries are visible before filtering")

        let search = app.textFields["journalSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("alpha")

        XCTAssertTrue(journalEntry(containing: "seeded-journal-marker-alpha")
            .waitForExistence(timeout: 5), "The matching entry must survive the filter")
        waitForAbsence(of: journalEntry(containing: "seeded-journal-marker-beta"),
                       "The non-matching entry must be filtered out")
    }

    func testClearingTheSearchRestoresEveryEntry() {
        launch(.seeded)
        openTab("Journey")

        let search = app.textFields["journalSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText("alpha")

        waitForAbsence(of: journalEntry(containing: "seeded-journal-marker-beta"),
                       "Precondition: the filter must have taken effect before it is cleared")

        // Delete the query.
        search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 5))

        XCTAssertTrue(journalEntry(containing: "seeded-journal-marker-beta")
            .waitForExistence(timeout: 5), "Clearing the search must bring every entry back")
    }
}
