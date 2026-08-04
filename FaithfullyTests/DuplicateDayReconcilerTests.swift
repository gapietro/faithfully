import XCTest
import SwiftData
@testable import Faithfully

/// GRADE-006, repair half.
///
/// Two rows for one civil day inflate totals, category counts and therefore
/// badges, and put two identical-looking entries in the Journey timeline where
/// editing one leaves the other. Streak and the calendar grid are already
/// immune — one works on a `Set` of day keys, the other de-dupes when building
/// the month.
///
/// The completion row itself is close to worthless: `challengeId` and category
/// are derivable from the date, and `completedDate` only orders the timeline.
/// The reflection is the only irreplaceable thing in the pair, so the rule is
/// not "pick a winner" — it is "end up with one row that still holds everything
/// the user wrote".
final class DuplicateDayReconcilerTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var persistence: PersistenceCoordinator!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        persistence = PersistenceCoordinator(context: context)
    }

    private let day = Date.from(year: 2026, month: 6, day: 15)

    @discardableResult
    private func insert(journal: String?, completedAtHour hour: Int, challengeId: String = "c1") -> CompletedChallenge {
        let completion = CompletedChallenge(
            challengeId: challengeId,
            challengeCategory: "prayer",
            completedDate: day.addingTimeInterval(Double(hour) * 3600),
            scheduledDate: day.startOfDay,
            dayKey: CivilDay.key(for: day),
            journalEntry: journal
        )
        persistence.insert(completion)
        return completion
    }

    private func rows() throws -> [CompletedChallenge] {
        try context.fetch(FetchDescriptor<CompletedChallenge>())
    }

    // MARK: - Nothing to do

    func testAStoreWithNoDuplicatesIsUntouched() throws {
        insert(journal: "kept", completedAtHour: 0)
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 0)
        XCTAssertEqual(try rows().count, 1)
        XCTAssertEqual(try rows().first?.journalEntry, "kept")
    }

    func testDifferentDaysAreNeverMerged() throws {
        insert(journal: "monday", completedAtHour: 0)
        let other = CompletedChallenge(
            challengeId: "c2", challengeCategory: "prayer",
            completedDate: day.addingDays(1), scheduledDate: day.addingDays(1).startOfDay,
            journalEntry: "tuesday"
        )
        persistence.insert(other)
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 0)
        XCTAssertEqual(try rows().count, 2)
    }

    // MARK: - Merging

    func testOnlyOneRowHasTextSoThatTextSurvives() throws {
        insert(journal: nil, completedAtHour: 0)
        insert(journal: "the reflection", completedAtHour: 1)
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 1)
        XCTAssertEqual(try rows().count, 1)
        XCTAssertEqual(try rows().first?.journalEntry, "the reflection",
                       "Writing must never be dropped in favour of an empty row")
    }

    func testIdenticalTextIsNotDoubled() throws {
        insert(journal: "same words", completedAtHour: 0)
        insert(journal: "same words", completedAtHour: 1)
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 1)
        XCTAssertEqual(try rows().first?.journalEntry, "same words")
    }

    func testTwoDifferentReflectionsAreBothKept() throws {
        insert(journal: "first thought", completedAtHour: 0)
        insert(journal: "second thought", completedAtHour: 5)
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 1)
        let merged = try XCTUnwrap(rows().first?.journalEntry)
        XCTAssertEqual(merged, "first thought\n\nsecond thought",
                       "Both are the user's writing for that day; neither may be discarded")
    }

    func testMergedTextFollowsCompletionOrderNotInsertionOrder() throws {
        insert(journal: "written later", completedAtHour: 9)
        insert(journal: "written first", completedAtHour: 2)
        try persistence.save()

        _ = try CompletionReconciler.mergeDuplicateDays(in: persistence)
        XCTAssertEqual(try rows().first?.journalEntry, "written first\n\nwritten later")
    }

    func testThreeRowsCollapseToOneKeepingEveryDistinctReflection() throws {
        insert(journal: "one", completedAtHour: 0)
        insert(journal: nil, completedAtHour: 1)
        insert(journal: "two", completedAtHour: 2)
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 1)
        XCTAssertEqual(try rows().count, 1)
        XCTAssertEqual(try rows().first?.journalEntry, "one\n\ntwo")
    }

    func testTheEarliestCompletionSurvives() throws {
        let earliest = insert(journal: nil, completedAtHour: 1, challengeId: "the-real-one")
        insert(journal: nil, completedAtHour: 8, challengeId: "the-duplicate")
        try persistence.save()

        _ = try CompletionReconciler.mergeDuplicateDays(in: persistence)
        let survivor = try XCTUnwrap(rows().first)
        XCTAssertEqual(survivor.id, earliest.id, "The completion that actually happened first must win")
        XCTAssertEqual(survivor.challengeId, "the-real-one")
    }

    func testAllRowsEmptyLeavesTheDayWithoutAReflection() throws {
        insert(journal: nil, completedAtHour: 0)
        insert(journal: "   ", completedAtHour: 1)
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 1)
        XCTAssertEqual(try rows().count, 1)
        XCTAssertNil(try rows().first?.journalEntry, "Whitespace is not a reflection")
    }

    /// The limit bounds what someone can *type*; it is not a licence for a
    /// repair to throw writing away. If they ever open the entry the editor
    /// already handles over-limit text — red counter, Save disabled until
    /// trimmed — which is a far better outcome than silently losing half of it.
    func testMergedTextIsKeptWholeEvenWhenItExceedsTheEditorLimit() throws {
        let long = String(repeating: "a", count: Constants.maxJournalLength - 10)
        let alsoLong = String(repeating: "b", count: Constants.maxJournalLength - 10)
        insert(journal: long, completedAtHour: 0)
        insert(journal: alsoLong, completedAtHour: 1)
        try persistence.save()

        _ = try CompletionReconciler.mergeDuplicateDays(in: persistence)
        let merged = try XCTUnwrap(rows().first?.journalEntry)
        XCTAssertTrue(merged.contains(long))
        XCTAssertTrue(merged.contains(alsoLong))
        XCTAssertGreaterThan(merged.count, Constants.maxJournalLength)
    }

    // MARK: - The sentinel key is not a day

    /// The worst thing this could possibly do. `backfillDayKeys` runs first and
    /// is best-effort; if it ever fails, every unmigrated row still carries the
    /// sentinel key 0. Treating that as a civil day would collapse the user's
    /// entire history into one row and concatenate every reflection they have
    /// ever written.
    func testUnmigratedRowsAreNeverMergedIntoEachOther() throws {
        for (index, offset) in (0..<5).enumerated() {
            let date = day.addingDays(-offset)
            let row = CompletedChallenge(
                challengeId: "c\(index)", challengeCategory: "prayer",
                completedDate: date, scheduledDate: date.startOfDay,
                dayKey: CompletedChallenge.unmigratedDayKey,
                journalEntry: "reflection \(index)"
            )
            persistence.insert(row)
        }
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 0,
                       "The sentinel is 'not yet migrated', not 'the same day'")
        XCTAssertEqual(try rows().count, 5, "A whole history must survive a failed backfill")
        XCTAssertEqual(Set(try rows().compactMap(\.journalEntry)).count, 5)
    }

    func testMigratedDuplicatesStillMergeWhileUnmigratedRowsAreLeftAlone() throws {
        let unmigrated = CompletedChallenge(
            challengeId: "old", challengeCategory: "prayer",
            completedDate: day.addingDays(-9), scheduledDate: day.addingDays(-9).startOfDay,
            dayKey: CompletedChallenge.unmigratedDayKey, journalEntry: "from before"
        )
        persistence.insert(unmigrated)
        insert(journal: "a", completedAtHour: 0)
        insert(journal: "b", completedAtHour: 1)
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 1)
        XCTAssertEqual(try rows().count, 2)
        XCTAssertEqual(try rows().first { $0.dayKey == CompletedChallenge.unmigratedDayKey }?.journalEntry,
                       "from before")
    }

    // MARK: - Safe to run on every launch

    func testRunningTwiceChangesNothingTheSecondTime() throws {
        insert(journal: "first thought", completedAtHour: 0)
        insert(journal: "second thought", completedAtHour: 5)
        try persistence.save()

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 1)
        let afterFirst = try XCTUnwrap(rows().first?.journalEntry)

        XCTAssertEqual(try CompletionReconciler.mergeDuplicateDays(in: persistence), 0,
                       "A repaired store has nothing left to repair")
        XCTAssertEqual(try rows().first?.journalEntry, afterFirst)
    }

    func testTotalsAgreeWithTheStoreAfterRepair() throws {
        insert(journal: "a", completedAtHour: 0)
        insert(journal: "b", completedAtHour: 1)
        try persistence.save()

        _ = try CompletionReconciler.mergeDuplicateDays(in: persistence)

        let challenges = try TestHelpers.loadTestChallenges()
        let badgeService = BadgeService(persistence: persistence)
        let service = try ChallengeService(
            persistence: persistence, challenges: challenges, badgeService: badgeService,
            enrollmentDate: TestHelpers.longEnrolledDate, dateProvider: { self.day }
        )
        XCTAssertEqual(service.fetchAllCompletions().count, 1,
                       "One day completed once must count once")
    }
}
