import SwiftUI

struct ChallengeCardView: View {
    let challenge: DailyChallenge
    let translation: BibleTranslation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category badge
            Text(challenge.category.displayName)
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
                .accessibilityIdentifier("categoryBadge")

            // Title
            Text(challenge.title)
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("challengeTitle")

            // Scripture
            VStack(alignment: .leading, spacing: 8) {
                Text(challenge.scriptureText(for: translation))
                    .font(.body)
                    .italic()
                    .accessibilityIdentifier("scriptureText")
                Text("— \(challenge.scriptureReference)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Challenge description
            Text(challenge.challengeDescription)
                .font(.body)
                .accessibilityIdentifier("challengeDescription")

            // Reflection prompt
            Text(challenge.reflectionPrompt)
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
