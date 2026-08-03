import Foundation

/// Why a journal edit could not be saved.
///
/// Deliberately not `CompletionFailure`. Its `.beforeEnrollment`,
/// `.gracePeriodExpired` and `.alreadyCompleted` cases cannot occur for an edit,
/// and a type whose cases cannot occur is a type that lies about its contract.
enum JournalEditFailure: Error, Equatable {
    case tooLong(limit: Int, actual: Int)
    case entryNotFound
    case couldNotRead
    case couldNotSave

    var message: String {
        switch self {
        case .tooLong(let limit, let actual):
            let over = actual - limit
            return "Your reflection is \(over) character\(over == 1 ? "" : "s") over the "
                + "\(limit)-character limit. Shorten it and try again — nothing has changed yet."
        case .entryNotFound:
            return "That day's record couldn't be found, so nothing was changed."
        case .couldNotRead:
            return "Your reflection couldn't be loaded, so nothing was changed. Please try again."
        case .couldNotSave:
            return "That change couldn't be saved. Your reflection is unchanged — please try again."
        }
    }
}

/// The outcome of editing or clearing a reflection.
///
/// Callers must not dismiss the editor until they have seen `.saved`; anything
/// else means the user's text exists only in the sheet they are looking at.
enum JournalEditResult: Equatable {
    case saved
    case failed(JournalEditFailure)

    var isSaved: Bool { self == .saved }
}
