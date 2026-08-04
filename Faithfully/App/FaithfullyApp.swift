import SwiftUI
import SwiftData

@main
struct FaithfullyApp: App {
    @State private var stack: PersistenceStack.Outcome
    @State private var appEnvironment: AppEnvironment

    init() {
        let outcome = Self.initialOutcome()
        #if DEBUG
        // Before the environment is built, so the graph reads seeded state.
        if let scenario = UITestSupport.requestedScenario {
            UITestSupport.apply(scenario, in: Self.container(for: outcome).mainContext)
        }
        #endif
        _stack = State(initialValue: outcome)
        _appEnvironment = State(initialValue: AppEnvironment(
            modelContext: Self.container(for: outcome).mainContext,
            storeFailure: Self.failure(for: outcome)
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(onResetStore: resetStore)
                .environment(appEnvironment)
        }
        .modelContainer(Self.container(for: stack))
    }

    /// Rebuilds the whole stack after the user chooses to reset an unreadable
    /// store. Reached only from the recovery screen, and re-entrant: a reset
    /// that does not recover leaves the banner up, and the next attempt has to
    /// work exactly as the first did.
    private func resetStore() {
        let outcome = Self.outcomeAfterReset()
        stack = outcome
        appEnvironment = AppEnvironment(
            modelContext: Self.container(for: outcome).mainContext,
            storeFailure: Self.failure(for: outcome)
        )
    }

    /// The stack the app launches on. A DEBUG launch argument can substitute the
    /// degraded outcome, so UI tests can reach the store-unavailable banner
    /// without a corrupt store on disk.
    private static func initialOutcome() -> PersistenceStack.Outcome {
        #if DEBUG
        if UITestSupport.forcesStoreFailure { return PersistenceStack.simulatedFailure() }
        #endif
        return PersistenceStack.open()
    }

    /// The outcome of a user-requested reset.
    ///
    /// Under the UI-test hook the failure is sticky, which models the case the
    /// recovery screen exists for and is the only way to exercise a *second*
    /// attempt: the store stays unreadable, so the banner and its button must
    /// still work. It also means a UI test never moves a real store file aside.
    private static func outcomeAfterReset() -> PersistenceStack.Outcome {
        #if DEBUG
        if UITestSupport.forcesStoreFailure { return PersistenceStack.simulatedFailure() }
        #endif
        return PersistenceStack.resetStore()
    }

    private static func container(for outcome: PersistenceStack.Outcome) -> ModelContainer {
        switch outcome {
        case .ready(let container), .degraded(let container, _): return container
        }
    }

    private static func failure(for outcome: PersistenceStack.Outcome) -> PersistenceError? {
        if case .degraded(_, let error) = outcome { return error }
        return nil
    }
}
