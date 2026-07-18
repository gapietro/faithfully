import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void
    @State private var currentPage = 0

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
                    onComplete()
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
