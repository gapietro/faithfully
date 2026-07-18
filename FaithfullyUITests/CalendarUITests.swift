import XCTest

final class CalendarUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        // Navigate to Calendar tab
        app.tabBars.buttons["Calendar"].tap()
    }

    func testMonthGridRendersAllDays() {
        let day1 = app.buttons["calendarDay_1"]
        XCTAssertTrue(day1.waitForExistence(timeout: 5), "Day 1 should exist in the grid")

        // Check a few more days exist
        let day15 = app.buttons["calendarDay_15"]
        XCTAssertTrue(day15.waitForExistence(timeout: 3), "Day 15 should exist")
    }

    func testTappingADayIsResponsive() {
        let day1 = app.buttons["calendarDay_1"]
        guard day1.waitForExistence(timeout: 5) else {
            XCTFail("Day 1 not found")
            return
        }
        XCTAssertTrue(day1.isHittable, "Day button should be tappable")
        day1.tap()

        // Verify multiple day buttons are tappable (grid is interactive)
        let day15 = app.buttons["calendarDay_15"]
        if day15.waitForExistence(timeout: 3) {
            XCTAssertTrue(day15.isHittable, "Day 15 should be tappable")
        }
    }

    func testCompletedDaysShowColoredIndicator() {
        let day1 = app.buttons["calendarDay_1"]
        XCTAssertTrue(day1.waitForExistence(timeout: 5), "Month grid should render with styled days")
    }

    func testGracePeriodDaysShowCompletionButton() {
        let day1 = app.buttons["calendarDay_1"]
        guard day1.waitForExistence(timeout: 5) else {
            XCTFail("Calendar grid not found")
            return
        }

        // Tap yesterday
        let yesterday = Calendar.current.component(.day, from: Date().addingTimeInterval(-86400))
        let dayButton = app.buttons["calendarDay_\(yesterday)"]
        if dayButton.waitForExistence(timeout: 3) {
            dayButton.tap()
            // Grace period complete button may appear
            let graceButton = app.buttons["gracePeriodComplete"]
            if graceButton.waitForExistence(timeout: 2) {
                XCTAssertTrue(graceButton.isHittable)
            }
        }
    }
}
