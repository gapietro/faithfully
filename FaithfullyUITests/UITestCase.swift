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
        case atLimitJournal
    }

    var app: XCUIApplication!

    /// Pins the app's clock for every `launch` in this test case.
    ///
    /// Left nil, the app runs on the wall clock — which is what the calendar and
    /// grace-window tests want, since they assert against real dates. A subclass
    /// that measures *layout* sets this, because the daily challenge rotates and
    /// its text length moves everything below it (#89).
    var fixedDate: Date?

    /// Extra launch arguments a subclass wants on every launch, such as a
    /// Dynamic Type override.
    var extraLaunchArguments: [String] = []

    override func setUp() {
        continueAfterFailure = false
    }

    @discardableResult
    func launch(_ scenario: Scenario, onboardingComplete: Bool = true) -> XCUIApplication {
        app = XCUIApplication()
        app.launchArguments = [
            "-hasCompletedOnboarding", onboardingComplete ? "YES" : "NO",
            "-FaithfullyUITestScenario", scenario.rawValue
        ] + fixedDateArguments + extraLaunchArguments
        app.launch()
        return app
    }

    private var fixedDateArguments: [String] {
        guard let fixedDate else { return [] }
        let formatter = ISO8601DateFormatter()
        return ["-FaithfullyUITestFixedDate", formatter.string(from: fixedDate)]
    }

    /// Waits for an element to *go away*, which `exists` cannot do.
    ///
    /// `exists` samples once, immediately. Used straight after an action that
    /// takes effect asynchronously — typing into a search field, say — it reads
    /// the state before the change lands and passes on timing rather than on
    /// behaviour. That is what made `testClearingTheSearchRestoresEveryEntry`
    /// flake on a slower runner (#89).
    func waitForAbsence(
        of element: XCUIElement,
        timeout: TimeInterval = 5,
        _ message: String = "",
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: element)
        let result = XCTWaiter().wait(for: [gone], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "\(message) (element was still present after \(timeout)s)",
                       file: file, line: line)
    }

    /// Waits for a control to reach an enabled state, which `isEnabled` cannot do.
    ///
    /// `isEnabled` samples once, immediately — the same defect `waitForAbsence`
    /// exists for. Read straight after an action, it can observe the value from
    /// before SwiftUI's state update landed, so the test passes or fails on
    /// timing rather than on behaviour (#102).
    func wait(
        for element: XCUIElement,
        toBeEnabled enabled: Bool,
        _ message: String = "",
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isEnabled == %@", NSNumber(value: enabled)), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "\(message) (still \(element.isEnabled ? "enabled" : "disabled") after \(timeout)s)",
                       file: file, line: line)
    }

    /// Waits for an element's value to settle on `expected`, for the same reason
    /// as above: `value` read immediately after an action can be the old one.
    func waitForValue(
        _ element: XCUIElement,
        equals expected: String,
        _ message: String = "",
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expected), object: element)
        let result = XCTWaiter().wait(for: [expectation], timeout: timeout)
        XCTAssertEqual(result, .completed,
                       "\(message) (actual: \(element.value.map { "\($0)" } ?? "nil"))",
                       file: file, line: line)
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
        ] + fixedDateArguments + extraLaunchArguments
        app.launch()
        return app
    }

    /// Relaunches without reseeding, to prove something was persisted rather
    /// than merely held in memory.
    @discardableResult
    func relaunchPreservingState() -> XCUIApplication {
        app.terminate()
        app = XCUIApplication()
        // Carries the pinned clock and any launch overrides across the relaunch:
        // a test that fixed the date is asserting about a specific day, and the
        // second launch has to land on the same one.
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
            + fixedDateArguments + extraLaunchArguments
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
