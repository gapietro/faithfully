import SwiftUI

// MARK: - Brand Colors

extension Color {
    static let brandNavy = Color("Navy")
    static let brandGold = Color("Gold")
    static let brandCream = Color("Cream")
    static let brandForest = Color("Forest")
}

// MARK: - Typography

extension Font {
    /// Serif treatment for scripture passages; UI text stays sans-serif.
    static var scripture: Font {
        .system(.body, design: .serif)
    }

    static var scriptureReference: Font {
        .system(.caption, design: .serif)
    }
}

// MARK: - Category Icons

extension ChallengeCategory {
    /// SF Symbol used wherever the category appears as an icon
    /// (challenge card capsule, badge glyphs). Placeholder until real art.
    var iconName: String {
        switch self {
        case .prayer: return "hands.sparkles.fill"
        case .scripture: return "book.fill"
        case .obedience: return "checkmark.seal.fill"
        case .giving: return "gift.fill"
        case .evangelism: return "megaphone.fill"
        case .spiritualWarfare: return "shield.fill"
        case .discipline: return "figure.mind.and.body"
        case .worshipAndThanks: return "music.note"
        case .service: return "heart.circle.fill"
        case .growth: return "leaf.fill"
        }
    }
}
