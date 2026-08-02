import Foundation
import SwiftData

@Model
final class CompletedChallenge {
    /// Marks a row that arrived from the V1 schema and has not been backfilled
    /// yet. Distinguishable from any real key, all of which are positive.
    static let unmigratedDayKey = 0

    var id: UUID
    var challengeId: String
    var challengeCategory: String

    /// When the user tapped complete. Used for ordering the journal; never for
    /// deciding which day was completed.
    var completedDate: Date

    /// Kept for display and for migrating older rows. Not the identity of the
    /// day — reinterpreting this instant under a different time zone is exactly
    /// the bug `dayKey` exists to prevent.
    var scheduledDate: Date

    /// The civil day this completion belongs to, as `yyyyMMdd`. Frozen at write
    /// time and never recomputed, so travel, a time-zone change, or a DST
    /// transition cannot move a completion to a different day. See `CivilDay`.
    ///
    /// The `= 0` default is load-bearing, not cosmetic: without a schema default
    /// this mandatory attribute cannot be added to existing rows, and the store
    /// fails to open with "missing attribute values on mandatory destination
    /// attribute" — before `didMigrate` ever gets a chance to backfill. Rows
    /// still carrying 0 are unmigrated (see `unmigratedDayKey`).
    var dayKey: Int = 0

    var journalEntry: String?

    init(
        id: UUID = UUID(),
        challengeId: String,
        challengeCategory: String,
        completedDate: Date = .now,
        scheduledDate: Date,
        dayKey: Int? = nil,
        journalEntry: String? = nil
    ) {
        self.id = id
        self.challengeId = challengeId
        self.challengeCategory = challengeCategory
        self.completedDate = completedDate
        self.scheduledDate = scheduledDate
        self.dayKey = dayKey ?? CivilDay.key(for: scheduledDate)
        self.journalEntry = journalEntry
    }
}
