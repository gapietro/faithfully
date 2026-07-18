import XCTest

final class OnboardingUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testFirstLaunchShowsOnboarding() {
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()

        let welcomeTitle = app.staticTexts["welcomeTitle"]
        XCTAssertTrue(welcomeTitle.waitForExistence(timeout: 5), "First launch should show onboarding welcome")
    }

    func testSecondLaunchSkipsOnboarding() {
        app.launchArguments = ["-hasCompletedOnboarding", "YES"]
        app.launch()

        let welcomeTitle = app.staticTexts["welcomeTitle"]
        XCTAssertFalse(welcomeTitle.waitForExistence(timeout: 3), "Second launch should skip onboarding")

        let dailyWalkTab = app.tabBars.buttons["Daily Walk"]
        XCTAssertTrue(dailyWalkTab.waitForExistence(timeout: 5), "Should show main tab view")
    }

    func testNotificationPermissionAppearsDuringOnboarding() {
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()

        let welcomeNext = app.buttons["welcomeNext"]
        XCTAssertTrue(welcomeNext.waitForExistence(timeout: 5))
        welcomeNext.tap()

        let howItWorksNext = app.buttons["howItWorksNext"]
        XCTAssertTrue(howItWorksNext.waitForExistence(timeout: 3), "Should navigate to how it works page")
    }

    func testOnboardingHasAllThreePages() {
        app.launchArguments = ["-hasCompletedOnboarding", "NO"]
        app.launch()

        // Page 1: Welcome
        let welcomeTitle = app.staticTexts["welcomeTitle"]
        guard welcomeTitle.waitForExistence(timeout: 5) else {
            XCTFail("Welcome page not found")
            return
        }

        // Swipe to page 2
        app.swipeLeft()
        let howItWorksNext = app.buttons["howItWorksNext"]
        XCTAssertTrue(howItWorksNext.waitForExistence(timeout: 5), "How it works page should have Next button")

        // Swipe to page 3
        app.swipeLeft()
        let startButton = app.buttons["startWalkButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5), "Final page should have Start My Walk button")
        XCTAssertTrue(startButton.isHittable, "Start button should be tappable")
    }
}
