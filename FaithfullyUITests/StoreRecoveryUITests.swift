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
