import XCTest

/// Shared launch plumbing so every test states the state it needs.
///
/// The previous suite launched against whatever the simulator happened to hold,
/// which is why so many tests could only assert that an element existed.
class UITestCase: XCTestCase {

    enum Scenario: String {
        case fresh
        case seeded
        case completedToday
        case graceAvailable
    }

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    @discardableResult
    func launch(_ scenario: Scenario, onboardingComplete: Bool = true) -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", onboardingComplete ? "YES" : "NO",
            "-FaithfullyUITestScenario", scenario.rawValue
        ]
        app.launch()
        return app
    }

    /// Launches as if the on-disk store could not be opened, so the app is on
    /// its in-memory stand-in and the store-unavailable banner is on screen.
    @discardableResult
    func launchWithUnavailableStore(_ scenario: Scenario = .fresh) -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", "YES",
            "-FaithfullyUITestScenario", scenario.rawValue,
            "-FaithfullyUITestForceStoreFailure"
        ]
        app.launch()
        return app
    }

    /// Relaunches without reseeding, to prove something was persisted rather
    /// than merely held in memory.
    @discardableResult
    func relaunchPreservingState() -> XCUIApplication {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()
        return app
    }

    func openTab(_ name: String, file: StaticString = #filePath, line: UInt = #line) {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 10), "The \(name) tab must exist", file: file, line: line)
        tab.tap()
    }

    /// Fails with the element's actual value, so a red test says what was wrong
    /// rather than only that something was.
    func assertValue(
        _ element: XCUIElement,
        equals expected: String,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(message): element not found", file: file, line: line)
        let actual = element.value as? String
        XCTAssertEqual(actual, expected, "\(message) (actual: \(actual ?? "nil"))", file: file, line: line)
    }

    /// SwiftUI decides for itself whether a combined accessibility element
    /// surfaces as `otherElements` or `staticTexts`, and it differs by
    /// container. Querying by identifier across the whole app avoids writing
    /// that implementation detail into every assertion.
    func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    func intValue(of identifier: String) -> Int? {
        let element = app.staticTexts[identifier]
        guard element.waitForExistence(timeout: 10) else { return nil }
        return Int(element.label)
    }

    func assertStat(
        _ identifier: String,
        equals expected: Int,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actual = intValue(of: identifier)
        XCTAssertEqual(actual, expected, "\(message) (actual: \(actual.map(String.init) ?? "not found"))",
                       file: file, line: line)
    }

    /// Brings the day-detail panel into view after selecting a day; on a short
    /// screen it sits below the month grid.
    func revealDayDetail() {
        if !app.staticTexts["calendarDetailTitle"].waitForExistence(timeout: 3) {
            app.swipeUp()
            _ = app.staticTexts["calendarDetailTitle"].waitForExistence(timeout: 3)
        }
    }

    func dayButton(_ day: Int) -> XCUIElement {
        app.buttons["calendarDay_\(day)"]
    }

    func dayNumber(daysAgo: Int) -> Int {
        Calendar.current.component(.day, from: Date().addingTimeInterval(Double(-daysAgo) * 86_400))
    }

    /// The calendar date `daysAgo` days before now — the same clock the app
    /// itself uses to seed scenarios and decide today.
    func targetDate(daysAgo: Int) -> Date {
        Date().addingTimeInterval(Double(-daysAgo) * 86_400)
    }

    /// Taps the calendar's month navigation until the displayed month contains
    /// `date`. Lets a test reach a specific day deterministically on every day
    /// of the year, rather than skipping whenever `daysAgo` lands in a
    /// different month than "today".
    func navigateToMonth(containing date: Date, file: StaticString = #filePath, line: UInt = #line) {
        let delta = monthDelta(from: Date(), to: date)
        guard delta != 0 else { return }
        let button = app.buttons[delta < 0 ? "previousMonth" : "nextMonth"]
        for _ in 0..<abs(delta) {
            XCTAssertTrue(button.waitForExistence(timeout: 5),
                          "Month navigation button must exist", file: file, line: line)
            button.tap()
        }
    }

    private func monthDelta(from: Date, to: Date) -> Int {
        let calendar = Calendar.current
        let start = calendar.dateComponents([.year, .month], from: from)
        let end = calendar.dateComponents([.year, .month], from: to)
        guard let startYear = start.year, let startMonth = start.month,
              let endYear = end.year, let endMonth = end.month else { return 0 }
        return (endYear - startYear) * 12 + (endMonth - startMonth)
    }
}
