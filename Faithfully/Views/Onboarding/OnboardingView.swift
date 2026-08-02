import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    /// Runs before finishing so the system permission prompt appears as part of
    /// onboarding; injected by the composition root.
    ///
    /// `@MainActor` because the caller hands it the app's service graph, which is
    /// not `Sendable`. Without the annotation the closure is nonisolated, so
    /// passing `services` into it is sending a non-Sendable value across an
    /// isolation boundary — a data race under Swift 6, and a real one: those
    /// objects are only ever touched from the UI.
    var requestNotificationPermission: (@MainActor () async -> Void)? = nil
    @State private var currentPage = 0
    @State private var isFinishing = false

    var body: some View {
        TabView(selection: $currentPage) {
            // Welcome
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "figure.walk")
                    .font(.system(size: 80))
                    .foregroundStyle(Color.accentColor)
                Text("Welcome to Faithfully")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityIdentifier("welcomeTitle")
                Text("Your daily walk with Jesus.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Next") { currentPage = 1 }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("welcomeNext")
            }
            .padding()
            .tag(0)

            // How it works
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "list.bullet.clipboard")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.accentColor)
                Text("One Challenge a Day")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Every day, you'll receive a scripture-backed challenge to put your faith into action.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Next") { currentPage = 2 }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("howItWorksNext")
            }
            .padding()
            .tag(1)

            // Get started
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green)
                Text("Ready to Walk?")
                    .font(.title)
                    .fontWeight(.bold)
                Text("Let's begin your journey of faith in action.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Start My Walk") {
                    guard !isFinishing else { return }
                    isFinishing = true
                    Task {
                        await requestNotificationPermission?()
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("startWalkButton")
            }
            .padding()
            .tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .accessibilityIdentifier("onboardingView")
    }
}
