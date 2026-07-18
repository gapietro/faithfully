import SwiftUI
import SwiftData

@main
struct FaithfullyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            UserProfile.self,
            CompletedChallenge.self,
            EarnedBadge.self
        ])
    }
}
