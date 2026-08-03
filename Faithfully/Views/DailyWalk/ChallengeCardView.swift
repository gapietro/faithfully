import SwiftUI

struct ChallengeCardView: View {
    let challenge: DailyChallenge
    let translation: BibleTranslation

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Category badge
            Label(challenge.category.displayName, systemImage: challenge.category.iconName)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.brandForest)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.brandForest.opacity(0.12))
                .clipShape(Capsule())
                .accessibilityIdentifier("categoryBadge")

            // Title
            Text(challenge.title)
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityIdentifier("challengeTitle")

            // Scripture — serif per design direction; UI text stays sans
            VStack(alignment: .leading, spacing: 8) {
                Text(challenge.scriptureText(for: translation))
                    .font(.scripture)
                    .italic()
                    .accessibilityIdentifier("scriptureText")
                Text("— \(challenge.scriptureReference)")
                    .font(.scriptureReference)
                    .foregroundStyle(Color.supportingText)
            }

            Divider()

            // Challenge description
            Text(challenge.challengeDescription)
                .font(.body)
                .accessibilityIdentifier("challengeDescription")

            // Reflection prompt
            Text(challenge.reflectionPrompt)
                .font(.callout)
                .foregroundStyle(Color.supportingText)
                .italic()
        }
        .padding()
        .background(Color.brandCream)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }
}
