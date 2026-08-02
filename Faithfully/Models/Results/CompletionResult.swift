import Foundation

/// Why a completion attempt could not be recorded.
///
/// Every case carries a message the user actually sees. A completion must never
/// fail silently, and must never look like it succeeded when it did not — the
/// journal is private, user-authored content that exists nowhere else.
enum CompletionFailure: Equatable {
    case journalTooLong(limit: Int, actual: Int)
    case beforeEnrollment
    case gracePeriodExpired
    case alreadyCompleted
    case couldNotSave

    init(_ error: ChallengeServiceError) {
        switch error {
        case .journalTooLong(let limit, let actual):
            self = .journalTooLong(limit: limit, actual: actual)
        case .beforeEnrollment:
            self = .beforeEnrollment
        case .gracePeriodExpired:
            self = .gracePeriodExpired
        case .alreadyCompleted:
            self = .alreadyCompleted
        case .emptyChallengePool:
            self = .couldNotSave
        }
    }

    var message: String {
        switch self {
        case .journalTooLong(let limit, let actual):
            let over = actual - limit
            return "Your reflection is \(over) character\(over == 1 ? "" : "s") over the "
                + "\(limit)-character limit. Shorten it and try again — nothing has been saved yet."
        case .beforeEnrollment:
            return "This day is before you started Faithfully, so it can't be completed."
        case .gracePeriodExpired:
            return "This day is outside the three-day grace period and can no longer be completed."
        case .alreadyCompleted:
            return "You've already completed this day."
        case .couldNotSave:
            return "Your reflection couldn't be saved. It's still here — please try again."
        }
    }
}

/// The outcome of a completion attempt.
///
/// Callers must not dismiss the editor or clear the draft until they have seen
/// `.completed`. Returning `Void` here is what allowed the sheet to throw away a
/// user's reflection on a failed save.
enum CompletionResult: Equatable {
    case completed(newBadges: [BadgeDefinition])
    case failed(CompletionFailure)

    var isCompleted: Bool {
        if case .completed = self { return true }
        return false
    }
}
