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
            let container = try ModelContainer(
                for: Schema(models),
                migrationPlan: FaithfullyMigrationPlan.self
            )
            applyFileProtection()
            return .ready(container)
        } catch {
            return degrade(after: error)
        }
    }

    /// Raises the store's data protection to `.complete`, so it is encrypted and
    /// unreadable whenever the device is locked.
    ///
    /// iOS defaults app-container files to
    /// `completeUntilFirstUserAuthentication`: readable from the first unlock
    /// after boot until the device powers off. That is a reasonable default for
    /// most data and the wrong one for this. A journal here holds someone's
    /// private religious reflection — confession, doubt, who they are struggling
    /// to forgive — which is the kind of content a lost phone should not give up.
    ///
    /// `.complete` is safe for this app specifically because it never runs
    /// outside the foreground: there are no background modes, no background
    /// fetch, and no app extensions. Notifications are handed to the system in
    /// advance and fire without touching the store, so nothing needs to read it
    /// while the device is locked. Adding any background work later means
    /// revisiting this — see docs/ship/DATA_PROTECTION.md.
    ///
    /// Best-effort by design: the store is already open and usable at this
    /// point, and failing to raise protection is not a reason to deny someone
    /// their app. It is retried on every launch.
    /// The protection class the store is opened with. Named rather than inlined
    /// so a change to it is a visible, testable edit instead of a one-word diff
    /// inside a method body.
    static let storeProtection: FileProtectionType = .complete

    @discardableResult
    static func applyFileProtection() -> Bool {
        guard let url = storeURL else { return false }
        var appliedToAll = true
        // The SQLite sidecars hold recently written pages, so protecting only
        // the main file would leave the newest journal entry less protected than
        // the rest.
        for path in [url.path, url.path + "-shm", url.path + "-wal"]
        where FileManager.default.fileExists(atPath: path) {
            do {
                try FileManager.default.setAttributes(
                    [.protectionKey: storeProtection], ofItemAtPath: path
                )
            } catch {
                appliedToAll = false
            }
        }
        return appliedToAll
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

    #if DEBUG
    /// The degraded outcome a UI test needs to reach the recovery banner,
    /// without having to corrupt a real store to get there.
    ///
    /// The banner is otherwise only reachable by making `ModelContainer.init`
    /// throw, so the one screen that guards the user's entire data store had no
    /// UI coverage at all — which is how a confirmation with no visible Cancel
    /// shipped on it. DEBUG-only, so no App Store build contains this path.
    static func simulatedFailure() -> Outcome {
        degrade(after: PersistenceError.storeUnavailable("simulated store failure (UI test)"))
    }
    #endif

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
