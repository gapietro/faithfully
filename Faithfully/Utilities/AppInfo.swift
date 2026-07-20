import Foundation

enum AppInfo {
    /// Canonical public privacy policy URL (App Store Connect + in-app).
    /// Hosted as a public gist until a first-party domain / GitHub Pages is enabled.
    static let privacyPolicyURL = URL(string: "https://gist.github.com/scoutapietro/96c48a68f12efe3950b5bc359db70974")!

    /// Direct raw HTML of the policy (useful for robots / diffing).
    static let privacyPolicyRawURL = URL(string: "https://gist.githubusercontent.com/scoutapietro/96c48a68f12efe3950b5bc359db70974/raw/index.html")!

    static func current(bundle: Bundle = .main) -> String {
        versionString(
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    static func versionString(version: String?, build: String?) -> String {
        switch (version, build) {
        case let (version?, build?):
            return "\(version) (\(build))"
        case let (version?, nil):
            return version
        default:
            return "Unknown"
        }
    }
}
