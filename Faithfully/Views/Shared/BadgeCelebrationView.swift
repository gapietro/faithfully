import SwiftUI

struct BadgeCelebrationView: View {
    let badges: [BadgeDefinition]
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.yellow)
                    .accessibilityIdentifier("celebrationIcon")

                Text("Badge Earned!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                ForEach(badges) { badge in
                    Text(badge.name)
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                Button("Continue") {
                    onDismiss()
                }
                .font(.headline)
                .padding(.horizontal, 40)
                .padding(.vertical, 12)
                .background(.white)
                .foregroundStyle(.black)
                .clipShape(Capsule())
                .accessibilityIdentifier("continueCelebration")
            }
        }
        .transition(.opacity)
    }
}
