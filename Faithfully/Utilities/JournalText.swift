import Foundation

enum JournalValidationError: Error, Equatable {
    case tooLong(limit: Int, actual: Int)
}

/// The single rule for turning raw editor text into something storable.
///
/// This lived inline in `completeChallenge`. Editing needs exactly the same
/// rule, and two copies of a length check is how the original truncation bug
/// would come back on the new path while the old one stayed fixed.
enum JournalText {
    /// Trims whitespace, treats an empty result as absent, and rejects
    /// over-limit text.
    ///
    /// Rejects rather than truncates: silently dropping the tail of a private
    /// reflection is data loss the user never consented to and cannot detect.
    /// Length is judged *after* trimming, so a trailing newline never costs
    /// someone their entry.
    static func validated(_ raw: String?) throws -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }

        guard trimmed.count <= Constants.maxJournalLength else {
            throw JournalValidationError.tooLong(
                limit: Constants.maxJournalLength,
                actual: trimmed.count
            )
        }
        return trimmed
    }
}
