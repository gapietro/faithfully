import Foundation
import SwiftData

/// Repairs a store that holds more than one completion for the same civil day.
///
/// ## Why this exists
///
/// A day can only be completed once — `ChallengeService.completeChallenge`
/// refuses otherwise, and since GRADE-006 it refuses even when the check itself
/// cannot be read, rather than guessing "not completed yet" from a failed
/// fetch. So a duplicate should be unreachable. This is the repair for a store
/// that already has one, from a build that shipped before that guard.
///
/// A duplicate inflates totals, category counts and therefore badges, and puts
/// two identical-looking entries in the Journey timeline where editing one
/// leaves the other. Streak and the calendar grid are already immune: one works
/// on a `Set` of day keys, the other de-dupes when building the month.
///
/// ## Why it merges rather than picks a winner
///
/// The completion row is nearly worthless — `challengeId` and category are
/// derivable from the date, because the scheduler is deterministic, and
/// `completedDate` only orders the timeline. The reflection is the one
/// irreplaceable thing in the pair.
///
/// So the rule is not "keep the better row". It is: keep the completion that
/// actually happened first, and give it **everything the user wrote that day**.
/// Distinct texts are joined by a blank line in completion order, so they read
/// as two paragraphs about the same day. Identical texts collapse to one.
///
/// Deliberately *not* `@Attribute(.unique)` on `dayKey`. SwiftData implements a
/// unique attribute as an upsert: a duplicate insert does not fail, it replaces
/// the existing row — verified in the simulator, where the second insert
/// silently took the first row's journal entry with it. That would turn a rare
/// duplicate into permanent loss of someone's private writing, which is worse
/// than the duplicate it prevents.
enum CompletionReconciler {

    /// Separator between two reflections merged into one day. A blank line, so
    /// the result reads as paragraphs rather than a run-on sentence.
    static let separator = "\n\n"

    /// Collapses every duplicated civil day to a single completion and returns
    /// how many days were repaired. Idempotent, and a no-op on a healthy store,
    /// so it is safe to run on every launch.
    @discardableResult
    static func mergeDuplicateDays(in persistence: PersistenceCoordinating) throws -> Int {
        let all = try persistence.fetch(FetchDescriptor<CompletedChallenge>())
        // Unmigrated rows all share the sentinel key 0, so they are not
        // duplicates of each other — they are a whole history that has not been
        // given its days yet. `backfillDayKeys` runs first and is best-effort;
        // if it ever fails, merging on the sentinel would collapse every
        // completion the user has into a single row. Skip them and let the next
        // launch backfill and then repair.
        let byDay = Dictionary(grouping: all.filter { $0.dayKey != CompletedChallenge.unmigratedDayKey },
                               by: \.dayKey)
        let duplicated = byDay.filter { $0.value.count > 1 }
        guard !duplicated.isEmpty else { return 0 }

        try persistence.transaction {
            for (_, rows) in duplicated {
                // Completion order, not insertion order: the timeline reads
                // chronologically and the earliest row is the one that set the day.
                let ordered = rows.sorted { $0.completedDate < $1.completedDate }
                guard let survivor = ordered.first else { continue }

                survivor.journalEntry = mergedJournal(from: ordered)
                for duplicate in ordered.dropFirst() {
                    persistence.delete(duplicate)
                }
            }
        }
        return duplicated.count
    }

    /// Every distinct, non-empty reflection in the group, in order, joined.
    ///
    /// The result is not length-checked. `Constants.maxJournalLength` bounds
    /// what someone can type; it is not a licence for a repair to throw writing
    /// away. If they ever open the merged entry the editor already handles
    /// over-limit text — the counter turns red and Save is disabled until it is
    /// trimmed — which is a far better outcome than silently losing half of it.
    private static func mergedJournal(from ordered: [CompletedChallenge]) -> String? {
        var seen = Set<String>()
        var texts: [String] = []
        for row in ordered {
            guard let trimmed = row.journalEntry?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !trimmed.isEmpty,
                  seen.insert(trimmed).inserted else { continue }
            texts.append(trimmed)
        }
        return texts.isEmpty ? nil : texts.joined(separator: separator)
    }
}
