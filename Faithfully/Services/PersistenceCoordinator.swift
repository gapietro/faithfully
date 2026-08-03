import Foundation
import SwiftData

enum PersistenceError: Error, Equatable {
    /// The store could not be opened at all — corrupt file, unreadable disk,
    /// incompatible schema. The app cannot run normally until this is resolved.
    case storeUnavailable(String)
    case fetchFailed(String)
    case saveFailed(String)

    /// Shown to the user. Deliberately says what survived and what to do, not
    /// what threw: "the operation couldn't be completed" tells nobody anything.
    var message: String {
        switch self {
        case .storeUnavailable:
            return "Faithfully couldn't open your saved data. Your challenges still work, "
                + "but completions and settings can't be read or written."
        case .fetchFailed:
            return "Faithfully couldn't read your saved data. Please try again."
        case .saveFailed:
            return "That change couldn't be saved. Nothing was lost — please try again."
        }
    }
}

/// The single boundary where SwiftData failures become typed results.
///
/// Before this existed, every service reached for `try? modelContext.save()`
/// directly: a full disk, a locked store, or a failed write returned the same
/// thing as a success, so the UI reported "done" for work that never happened.
protocol PersistenceCoordinating: AnyObject {
    var context: ModelContext { get }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T]
    func insert<T: PersistentModel>(_ model: T)

    /// Removes a model from the store. Like `insert`, it stages the change —
    /// the caller's `transaction` decides whether it commits.
    func delete<T: PersistentModel>(_ model: T)

    func save() throws

    /// Discards every unsaved change in the context. Called after a failed save
    /// so a rejected mutation cannot linger in memory and be committed later by
    /// an unrelated write.
    func rollback()

    /// Runs `body` and commits it as one unit. If either the body or the save
    /// fails, the context is rolled back, so partial state never survives —
    /// this is what makes a completion and the badges it earns atomic.
    func transaction(_ body: () throws -> Void) throws
}

extension PersistenceCoordinating {
    func transaction(_ body: () throws -> Void) throws {
        do {
            try body()
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}

final class PersistenceCoordinator: PersistenceCoordinating {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetch<T: PersistentModel>(_ descriptor: FetchDescriptor<T>) throws -> [T] {
        do {
            return try context.fetch(descriptor)
        } catch {
            throw PersistenceError.fetchFailed(String(describing: error))
        }
    }

    func insert<T: PersistentModel>(_ model: T) {
        context.insert(model)
    }

    func delete<T: PersistentModel>(_ model: T) {
        context.delete(model)
    }

    func save() throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            throw PersistenceError.saveFailed(String(describing: error))
        }
    }

    func rollback() {
        context.rollback()
    }
}
