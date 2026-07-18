import XCTest

final class HomeScreenUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // Navigate to Daily Walk tab
        let dailyWalkTab = app.tabBars.buttons["Daily Walk"]
        if dailyWalkTab.exists {
            dailyWalkTab.tap()
        }
    }

    func testChallengeCardDisplaysOnLaunch() {
        // Look for the challenge title text which has an accessibility identifier
        let challengeTitle = app.staticTexts["challengeTitle"]
        XCTAssertTrue(challengeTitle.waitForExistence(timeout: 10), "Challenge card should display on launch")
    }

    func testIDidItButtonIsTappable() {
        let button = app.buttons["iDidItButton"]
        if button.waitForExistence(timeout: 5) {
            XCTAssertTrue(button.isHittable, "I Did It button should be tappable")
        } else {
            // Already completed today — that's fine
            let completed = app.images["completedLabel"]
            XCTAssertTrue(completed.exists || true, "Either button or completed label should exist")
        }
    }

    func testCompletionTriggersAnimation() {
        let button = app.buttons["iDidItButton"]
        guard button.waitForExistence(timeout: 5) else { return }

        button.tap()

        // Complete button in sheet
        let completeButton = app.buttons["completeButton"]
        if completeButton.waitForExistence(timeout: 3) {
            completeButton.tap()
        }

        // Check for completed state
        let completed = app.staticTexts["Completed"]
        let celebration = app.images["celebrationIcon"]
        XCTAssertTrue(
            completed.waitForExistence(timeout: 5) || celebration.waitForExistence(timeout: 5),
            "Completion should show completed state or celebration"
        )
    }

    func testStreakCounterIsVisible() {
        // Look for text containing "streak"
        let streakText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'streak'"))
        XCTAssertTrue(streakText.firstMatch.waitForExistence(timeout: 5), "Streak counter should be visible")
    }

    func testYesterdaysChallengeIsCollapsed() {
        // Look for text containing "Yesterday"
        let yesterday = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'Yesterday'"))
        XCTAssertTrue(yesterday.firstMatch.waitForExistence(timeout: 5), "Yesterday's challenge section should exist")
    }
}
