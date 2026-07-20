import SwiftUI

struct ChallengeLoadErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            Text("Unable to Load Challenges")
                .font(.title2)
                .fontWeight(.bold)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") { onRetry() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("retryLoadButton")
        }
        .padding()
        .accessibilityIdentifier("challengeLoadError")
    }
}
