import SwiftUI

/// Shared badge artwork placeholder: a symbol in a circular medallion.
/// Earned badges get full brand color; unearned badges are grayscale
/// silhouettes. Used by the Journey grid and the celebration overlay.
/// Structure is ready to swap the symbol for real art assets later.
struct BadgeGlyphView: View {
    let type: BadgeType
    let category: ChallengeCategory?
    let isEarned: Bool
    var size: CGFloat = 44

    private var symbolName: String {
        switch type {
        case .journey: return "figure.run"
        case .streak: return "flame.fill"
        case .category: return category?.iconName ?? "medal.fill"
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(isEarned ? AnyShapeStyle(medallionGradient) : AnyShapeStyle(Color(.systemGray5)))
            Circle()
                .strokeBorder(isEarned ? Color.brandGold : Color(.systemGray3), lineWidth: size / 22)
            Image(systemName: symbolName)
                .font(.system(size: size * 0.45, weight: .semibold))
                .foregroundStyle(isEarned ? Color.white : Color(.systemGray))
        }
        .frame(width: size, height: size)
        .opacity(isEarned ? 1 : 0.55)
        .accessibilityHidden(true)
    }

    private var medallionGradient: LinearGradient {
        LinearGradient(
            colors: [.brandGold, .brandNavy],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
