import SwiftUI

struct BadgeCelebrationView: View {
    let badges: [BadgeDefinition]
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealed = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if let first = badges.first {
                    BadgeGlyphView(
                        type: first.type,
                        category: first.category,
                        isEarned: true,
                        size: 96
                    )
                    .accessibilityIdentifier("celebrationIcon")
                }

                Text("Badge Earned!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                ForEach(badges) { badge in
                    Text(badge.name)
                        .font(.title2)
                        .foregroundStyle(Color.brandGold)
                }

                Button("Continue") {
                    onDismiss()
                }
                .font(.headline)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(.white)
                .foregroundStyle(Color.brandNavy)
                .clipShape(Capsule())
                .accessibilityIdentifier("continueCelebration")
            }
            // With Reduce Motion the content appears immediately, full-size;
            // otherwise it springs in with a light scale + fade.
            .scaleEffect(revealed || reduceMotion ? 1 : 0.6)
            .opacity(revealed || reduceMotion ? 1 : 0)
            .onAppear {
                guard !reduceMotion else {
                    revealed = true
                    return
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
                    revealed = true
                }
            }
        }
        .transition(.opacity)
    }
}
