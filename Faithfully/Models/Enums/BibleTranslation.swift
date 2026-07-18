import Foundation

enum BibleTranslation: String, Codable, CaseIterable, Identifiable {
    case esv
    case niv
    case nkjv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .esv: return "ESV"
        case .niv: return "NIV"
        case .nkjv: return "NKJV"
        }
    }
}
