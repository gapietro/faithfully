import Foundation

enum BibleTranslation: String, Codable, CaseIterable, Identifiable {
    case web
    case kjv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .web: return "WEB"
        case .kjv: return "KJV"
        }
    }

    var fullName: String {
        switch self {
        case .web: return "World English Bible"
        case .kjv: return "King James Version"
        }
    }

    /// Profiles saved before the public-domain v1 may hold esv/niv/nkjv raw
    /// values; decode those (or anything else unknown) as the WEB default
    /// instead of failing the whole model load.
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BibleTranslation(rawValue: raw) ?? .web
    }
}
