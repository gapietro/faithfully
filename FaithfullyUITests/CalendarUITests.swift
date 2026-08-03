import XCTest

final class CalendarUITests: UITestCase {

    func testMonthGridRendersEveryDayOfTheMonth() {
        launch(.seeded)
        openTab("Calendar")

        XCTAssertTrue(dayButton(1).waitForExistence(timeout: 10))
        let expectedDays = Calendar.current
            .range(of: .day, in: .month, for: Date())?.count ?? 0
        XCTAssertGreaterThan(expectedDays, 27)
        for day in [1, 15, expectedDays] {
            XCTAssertTrue(dayButton(day).exists, "Day \(day) must be in the grid")
        }
        XCTAssertFalse(dayButton(expectedDays + 1).exists,
                       "The grid must not contain a day beyond the month's length")
    }

    /// Was: assert day 1 exists. Status is conveyed by colour, which a UI test
    /// cannot see — it is now also an accessibility value, which it can.
    func testCompletedDaysAreDistinguishableFromIncompleteOnes() {
        launch(.completedToday)
        openTab("Calendar")

        let todayNumber = dayNumber(daysAgo: 0)
        assertValue(dayButton(todayNumber), equals: "Completed",
                    "A completed today must be marked completed")

        // A future day in the same month must not read as completed.
        let expectedDays = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 28
        if todayNumber < expectedDays {
            assertValue(dayButton(todayNumber + 1), equals: "Upcoming",
                        "A day that has not happened must read as upcoming")
        }
    }

    func testIncompleteTodayIsMarkedTodayNotCompleted() {
        launch(.seeded)
        openTab("Calendar")

        assertValue(dayButton(dayNumber(daysAgo: 0)), equals: "Today, not yet completed",
                    "An open today must be distinguishable from a completed one")
    }

    // MARK: - Grace period (behavioural, not presence)

    func testGraceDayOffersCompletionAndRecordsIt() {
        launch(.graceAvailable)
        openTab("Calendar")
        navigateToMonth(containing: targetDate(daysAgo: 1))

        let yesterday = dayButton(dayNumber(daysAgo: 1))
        assertValue(yesterday, equals: "Missed, can still be completed",
                    "Yesterday must be inside the grace window in this scenario")
        yesterday.tap()
        revealDayDetail()
        XCTAssertTrue(app.staticTexts["calendarDetailTitle"].waitForExistence(timeout: 5),
                      "Tapping a day must open its detail panel")

        let complete = app.buttons["gracePeriodComplete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5),
                      "A recoverable day must actually offer completion")
        complete.tap()

        assertValue(dayButton(dayNumber(daysAgo: 1)), equals: "Completed",
                    "Recovering a grace day must mark it completed")
    }

    func testGraceRecoveryPersistsAndRaisesTheTotal() {
        launch(.graceAvailable)

        openTab("Journey")
        let before = intValue(of: "statTotalCompleted")
        XCTAssertNotNil(before)

        openTab("Calendar")
        navigateToMonth(containing: targetDate(daysAgo: 1))
        dayButton(dayNumber(daysAgo: 1)).tap()
        revealDayDetail()
        app.buttons["gracePeriodComplete"].tap()

        openTab("Journey")
        let after = intValue(of: "statTotalCompleted")
        XCTAssertEqual(after, (before ?? 0) + 1,
                       "A grace recovery must count toward the journey total")

        relaunchPreservingState()
        openTab("Journey")
        let afterRelaunch = intValue(of: "statTotalCompleted")
        XCTAssertEqual(afterRelaunch, after, "The recovery must survive a relaunch")
    }

    func testDayOutsideTheGraceWindowOffersNoCompletion() {
        launch(.graceAvailable)
        openTab("Calendar")
        navigateToMonth(containing: targetDate(daysAgo: 10))

        // Ten days ago is completed in this scenario; a completed day must not
        // offer completion either.
        let old = dayButton(dayNumber(daysAgo: 10))
        XCTAssertTrue(old.waitForExistence(timeout: 10))
        old.tap()
        revealDayDetail()
        XCTAssertTrue(app.staticTexts["calendarDetailTitle"].waitForExistence(timeout: 5),
                      "Precondition: the detail panel must open, or the next assertion is vacuous")
        XCTAssertFalse(app.buttons["gracePeriodComplete"].exists,
                       "A day outside the grace window must not be completable")
    }

    // MARK: - Enrollment boundary (CLEAN-002)

    func testDaysBeforeEnrollmentAreMarkedAndNotCompletable() {
        launch(.fresh)
        openTab("Calendar")

        // Enrollment in the `.fresh` scenario is always "today", so yesterday
        // is always before enrollment — true every day of the year, unlike
        // "day 1 of the current month", which today itself can be.
        navigateToMonth(containing: targetDate(daysAgo: 1))
        let earlier = dayButton(dayNumber(daysAgo: 1))
        assertValue(earlier, equals: "Before you started",
                    "A day before enrollment must not read as a miss")

        earlier.tap()
        revealDayDetail()
        XCTAssertTrue(app.staticTexts["preEnrollmentNotice"].waitForExistence(timeout: 5),
                      "The user must be told why the day is unavailable")
        XCTAssertFalse(app.buttons["gracePeriodComplete"].exists,
                       "A pre-enrollment day must not be completable")
    }

    func testMonthNavigationChangesTheDisplayedMonth() {
        launch(.seeded)
        openTab("Calendar")

        let title = app.staticTexts["monthTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let original = title.label

        app.buttons["previousMonth"].tap()
        XCTAssertNotEqual(title.label, original, "Navigating back must change the month shown")

        app.buttons["nextMonth"].tap()
        XCTAssertEqual(title.label, original, "Navigating forward must return to the original month")
    }
}
