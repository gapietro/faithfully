import Foundation
import SwiftData

/// Owns opening the SwiftData store, and is the one place that decides what to
/// do when it can't be opened.
///
/// This used to be a `fatalError` in `FaithfullyApp.init`, which turns a
/// corrupt store into an unbreakable crash loop: every launch dies in `init`,
/// so the user can never reach a screen that could explain or fix it. Their
/// only recourse is deleting the app, which also deletes their journal.
enum PersistenceStack {
    static let models: [any PersistentModel.Type] = [
        UserProfile.self, CompletedChallenge.self, EarnedBadge.self
    ]

    enum Outcome {
        case ready(ModelContainer)
        /// The store could not be opened. `container` is a working in-memory
        /// stand-in so the app still launches and can show the challenge and
        /// the explanation, rather than dying before any UI exists.
        case degraded(ModelContainer, PersistenceError)
    }

    static func open() -> Outcome {
        do {
            return .ready(try ModelContainer(
                for: Schema(models),
                migrationPlan: FaithfullyMigrationPlan.self
            ))
        } catch {
            return degrade(after: error)
        }
    }

    /// Moves the unreadable store aside and opens a fresh one. Destructive by
    /// nature, so it is only ever reached from an explicit user action on the
    /// recovery screen — never automatically.
    static func resetStore() -> Outcome {
        if let url = storeURL {
            let archived = url.deletingLastPathComponent()
                .appendingPathComponent("Faithfully-unreadable-\(Int(Date.now.timeIntervalSince1970)).store")
            // Moved, not deleted: an unreadable store may still be recoverable
            // by hand, and deleting it outright would discard the only copy of
            // the user's journal.
            try? FileManager.default.moveItem(at: url, to: archived)
            for suffix in ["-shm", "-wal"] {
                let sidecar = URL(fileURLWithPath: url.path + suffix)
                try? FileManager.default.removeItem(at: sidecar)
            }
        }
        return open()
    }

    static var storeURL: URL? {
        ModelConfiguration(schema: Schema(models)).url
    }

    private static func degrade(after error: Error) -> Outcome {
        let failure = PersistenceError.storeUnavailable(String(describing: error))
        do {
            let fallback = try ModelContainer(
                for: Schema(models),
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            return .degraded(fallback, failure)
        } catch {
            // An in-memory container failing means the schema itself is broken,
            // which is a programming error rather than a user-data problem.
            preconditionFailure("In-memory fallback container could not be created: \(error)")
        }
    }
}
