import XCTest

/// The store-unavailable banner and its reset confirmation.
///
/// This screen guards the most destructive action in the app — reset moves the
/// user's entire store aside, every completion and every journal entry — and
/// until now had no UI coverage, because reaching it meant corrupting a real
/// store. A DEBUG launch argument substitutes the degraded outcome instead.
final class StoreRecoveryUITests: UITestCase {

    func testResetConfirmationOffersAVisibleCancel() {
        launchWithUnavailableStore()

        XCTAssertTrue(element("storeUnavailableBanner").waitForExistence(timeout: 10),
                      "A store the app cannot open must be reported, not hidden")

        app.buttons["resetStoreButton"].tap()

        // The defect this guards: as a confirmationDialog, only the destructive
        // button reached the accessibility tree, so the sole action offered was
        // the irreversible one and Cancel existed only as a tap outside.
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5),
                      "Resetting the whole store must offer an explicit Cancel")
        XCTAssertTrue(app.buttons["Reset"].exists,
                      "The confirmation must still offer the reset itself")
    }

    /// GRADE-002: the handler was attached once from `.onAppear`, and resetting
    /// replaces the environment it was attached to. `.onAppear` does not fire
    /// again for the same view identity, so the button went dead after the
    /// first attempt — precisely when a store that is *still* unreadable needs
    /// it. Under the test hook the failure is sticky, so this drives the second
    /// attempt the old code could not survive.
    func testTheRecoveryButtonStillWorksAfterAResetThatDidNotRecover() {
        launchWithUnavailableStore()
        XCTAssertTrue(element("storeUnavailableBanner").waitForExistence(timeout: 10))

        // A reset rebuilds the whole graph on a fresh container, so anything
        // written to the in-memory stand-in since launch is gone afterwards.
        // That is the observable proof the handler actually ran — the banner
        // alone stays up either way.
        completeToday()
        reset()
        XCTAssertTrue(app.buttons["iDidItButton"].waitForExistence(timeout: 10),
                      "First reset must rebuild the store")

        // The second attempt. Under the old wiring the handler was attached
        // once from `.onAppear` and lost when the first reset replaced the
        // environment, so this tap did nothing at all.
        completeToday()
        reset()
        XCTAssertTrue(app.buttons["iDidItButton"].waitForExistence(timeout: 10),
                      "The recovery control must not go dead after one attempt")
        XCTAssertTrue(element("storeUnavailableBanner").exists,
                      "The store is still unreadable, so the warning stays up")
    }

    private func completeToday() {
        XCTAssertTrue(app.buttons["iDidItButton"].waitForExistence(timeout: 10))
        app.buttons["iDidItButton"].tap()
        XCTAssertTrue(app.buttons["completeButton"].waitForExistence(timeout: 5))
        app.buttons["completeButton"].tap()
        XCTAssertTrue(app.staticTexts["completedLabel"].waitForExistence(timeout: 10),
                      "Precondition: the day records against the in-memory stand-in")
    }

    private func reset() {
        app.buttons["resetStoreButton"].tap()
        XCTAssertTrue(app.buttons["Reset"].waitForExistence(timeout: 5),
                      "The reset confirmation must be reachable")
        app.buttons["Reset"].tap()
    }

    func testCancellingLeavesTheStoreAlone() {
        launchWithUnavailableStore()
        XCTAssertTrue(element("storeUnavailableBanner").waitForExistence(timeout: 10))

        app.buttons["resetStoreButton"].tap()
        XCTAssertTrue(app.buttons["Cancel"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()

        XCTAssertFalse(app.buttons["Reset"].waitForExistence(timeout: 2),
                       "Cancelling must dismiss the confirmation")
        XCTAssertTrue(element("storeUnavailableBanner").exists,
                      "Cancelling must not reset anything, so the warning stays")
    }
}
