import XCTest
@testable import Faithfully

final class AppInfoTests: XCTestCase {
    func testVersionStringWithVersionAndBuild() {
        XCTAssertEqual(AppInfo.versionString(version: "1.0", build: "1"), "1.0 (1)")
    }

    func testVersionStringWithVersionOnly() {
        XCTAssertEqual(AppInfo.versionString(version: "1.0", build: nil), "1.0")
    }

    func testVersionStringWithNeitherReturnsUnknown() {
        XCTAssertEqual(AppInfo.versionString(version: nil, build: nil), "Unknown")
        XCTAssertEqual(AppInfo.versionString(version: nil, build: "7"), "Unknown")
    }

    func testCurrentReadsHostAppBundle() {
        let current = AppInfo.current()
        XCTAssertNotEqual(current, "Unknown")
        XCTAssertTrue(current.hasPrefix("1."), "Expected marketing version starting with 1., got \(current)")
    }

    func testPrivacyPolicyURLIsHTTPS() {
        XCTAssertEqual(AppInfo.privacyPolicyURL.scheme, "https")
        XCTAssertFalse(AppInfo.privacyPolicyURL.absoluteString.isEmpty)
        XCTAssertTrue(AppInfo.privacyPolicyURL.absoluteString.contains("gist.github.com"))
    }

    func testPrivacyPolicyRawURLPointsAtPolicyHTML() {
        XCTAssertEqual(AppInfo.privacyPolicyRawURL.scheme, "https")
        XCTAssertTrue(AppInfo.privacyPolicyRawURL.absoluteString.hasSuffix("/raw/index.html")
            || AppInfo.privacyPolicyRawURL.path.contains("index.html"))
    }
}
