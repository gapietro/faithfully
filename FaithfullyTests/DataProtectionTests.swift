import XCTest
import SwiftData
@testable import Faithfully

/// Guards the two things about local data that a code change could silently
/// undo: the store's protection class, and the privacy manifest's contents.
///
/// Neither proves on-device behaviour. File protection is enforced by a hardware
/// key hierarchy the simulator does not have — it does not even report the
/// attribute back, so there is nothing to observe there. The manifest is only
/// ever judged by App Store validation. Both are verified on a device under #54.
///
/// What these tests do prove is that the app still *asks* for the right thing,
/// which is the part that regresses in a pull request.
final class DataProtectionTests: XCTestCase {

    func testStoreProtectionIsCompleteAndNotTheOSDefault() {
        // iOS defaults app-container files to completeUntilFirstUserAuthentication,
        // which leaves the journal readable from the first unlock after boot
        // until the device powers off. Lowering to that default, or to .none,
        // fails here.
        XCTAssertEqual(PersistenceStack.storeProtection, .complete)
        XCTAssertNotEqual(PersistenceStack.storeProtection, .completeUntilFirstUserAuthentication)
    }

    func testApplyingProtectionIsSafeWhenNoStoreExistsYet() {
        // Called on every launch, including the first, before any file exists.
        XCTAssertNoThrow(PersistenceStack.applyFileProtection())
    }

    // MARK: - Privacy manifest

    private func privacyManifest() throws -> [String: Any] {
        let bundle = Bundle(for: type(of: self))
        let url = try XCTUnwrap(
            bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")
                ?? Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy must ship in the app bundle"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    func testPrivacyManifestDeclaresNoTrackingAndNoCollection() throws {
        let manifest = try privacyManifest()

        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((manifest["NSPrivacyTrackingDomains"] as? [Any])?.count, 0)
        XCTAssertEqual((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0,
                       "The app collects nothing; this must stay empty, not become unset")
    }

    func testPrivacyManifestDeclaresTheUserDefaultsReason() throws {
        let manifest = try privacyManifest()
        let apis = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])

        let userDefaults = apis.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        }
        let reasons = try XCTUnwrap(
            (userDefaults?["NSPrivacyAccessedAPITypeReasons"] as? [String]),
            "@AppStorage uses UserDefaults, a required-reason API, so it must be declared"
        )
        XCTAssertEqual(reasons, ["CA92.1"], "CA92.1 is the app-only, not-shared reason")
    }
}
