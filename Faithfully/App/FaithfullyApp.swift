import SwiftUI
import SwiftData

@main
struct FaithfullyApp: App {
    private let modelContainer: ModelContainer
    @State private var appEnvironment: AppEnvironment

    init() {
        do {
            let container = try ModelContainer(
                for: UserProfile.self, CompletedChallenge.self, EarnedBadge.self
            )
            modelContainer = container
            _appEnvironment = State(initialValue: AppEnvironment(modelContext: container.mainContext))
        } catch {
            fatalError("Unable to create SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appEnvironment)
        }
        .modelContainer(modelContainer)
    }
}
