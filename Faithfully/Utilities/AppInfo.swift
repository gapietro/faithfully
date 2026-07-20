import Foundation

enum AppInfo {
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
