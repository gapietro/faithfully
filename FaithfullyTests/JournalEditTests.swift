import XCTest
import SwiftData
@testable import Faithfully

final class JournalEditTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var persistence: InjectablePersistence!
    var badgeService: BadgeService!
    var service: ChallengeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        persistence = InjectablePersistence(context: context)
        badgeService = BadgeService(persistence: persistence)
        service = try ChallengeService(
            persistence: persistence,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: TestHelpers.longEnrolledDate,
            dateProvider: { Date.from(year: 2026, month: 6, day: 15) }
        )
    }

    /// Returns the id of a completion created with the given journal text.
    @discardableResult
    private func makeCompletion(journal: String?) throws -> UUID {
        let day = Date.from(year: 2026, month: 6, day: 15)
        _ = try service.completeChallenge(service.challengeForDate(day), on: day, journal: journal)
        return try XCTUnwrap(context.fetch(FetchDescriptor<CompletedChallenge>()).first).id
    }

    private func storedJournal() throws -> String? {
        try XCTUnwrap(context.fetch(FetchDescriptor<CompletedChallenge>()).first).journalEntry
    }

    private func text(ofLength length: Int) -> String {
        String(repeating: "a", count: length)
    }

    func testEditingReplacesTheText() throws {
        let id = try makeCompletion(journal: "first thoughts")

        XCTAssertEqual(service.updateJournal(entryID: id, to: "second thoughts"), .saved)
        XCTAssertEqual(try storedJournal(), "second thoughts")
    }

    func testClearingSetsTheJournalToNilNotEmptyString() throws {
        let id = try makeCompletion(journal: "regret this")

        XCTAssertEqual(service.updateJournal(entryID: id, to: nil), .saved)
        XCTAssertNil(try storedJournal(),
                     "An empty string would still render as an entry with blank text")
    }

    func testWhitespaceOnlyTextClearsTheEntry() throws {
        let id = try makeCompletion(journal: "regret this")

        XCTAssertEqual(service.updateJournal(entryID: id, to: "   \n  "), .saved)
        XCTAssertNil(try storedJournal())
    }

    func testAddingTextToACompletionThatHadNone() throws {
        let id = try makeCompletion(journal: nil)
        XCTAssertNil(try storedJournal())

        XCTAssertEqual(service.updateJournal(entryID: id, to: "added later"), .saved)
        XCTAssertEqual(try storedJournal(), "added later")
    }

    func testTextAtTheLimitIsAccepted() throws {
        let id = try makeCompletion(journal: "short")
        let atLimit = text(ofLength: Constants.maxJournalLength)

        XCTAssertEqual(service.updateJournal(entryID: id, to: atLimit), .saved)
        XCTAssertEqual(try storedJournal()?.count, Constants.maxJournalLength)
    }

    func testTextOverTheLimitIsRejectedAndNothingChanges() throws {
        let id = try makeCompletion(journal: "keep me")
        let over = text(ofLength: Constants.maxJournalLength + 1)

        XCTAssertEqual(
            service.updateJournal(entryID: id, to: over),
            .failed(.tooLong(limit: Constants.maxJournalLength,
                             actual: Constants.maxJournalLength + 1))
        )
        XCTAssertEqual(try storedJournal(), "keep me",
                       "A rejected edit must not damage the text it was editing")
    }

    func testUnknownEntryReportsNotFoundAndWritesNothing() throws {
        try makeCompletion(journal: "untouched")

        XCTAssertEqual(service.updateJournal(entryID: UUID(), to: "nope"), .failed(.entryNotFound))
        XCTAssertEqual(try storedJournal(), "untouched")
    }

    func testFailedSaveRollsBackAndKeepsTheOriginalText() throws {
        let id = try makeCompletion(journal: "original")
        persistence.failNextSave = true

        XCTAssertEqual(service.updateJournal(entryID: id, to: "replacement"), .failed(.couldNotSave))
        XCTAssertEqual(persistence.rollbackCount, 1)
        XCTAssertEqual(try storedJournal(), "original",
                       "A failed save must leave the stored reflection untouched")
    }

    // MARK: - The invariant this whole feature rests on

    func testEditingDoesNotMoveStreakTotalOrBadges() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        // 31 consecutive days earns the 5K journey badge.
        for offset in 0..<31 {
            let date = today.addingDays(-offset)
            let challenge = service.challengeForDate(date)
            context.insert(CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date.startOfDay,
                journalEntry: offset == 0 ? "the entry we will edit" : nil
            ))
        }
        try context.save()
        try persistence.transaction { _ = badgeService.evaluateAndStageAwards() }

        let streakBefore = service.calculateStreak()
        let totalBefore = service.fetchAllCompletions().count
        let badgesBefore = Set(badgeService.earnedBadges().map(\.badgeName))
        XCTAssertGreaterThan(streakBefore, 0)
        XCTAssertTrue(badgesBefore.contains("journey_5k"), "Precondition: a badge is earned")

        let target = try XCTUnwrap(
            context.fetch(FetchDescriptor<CompletedChallenge>())
                .first { $0.journalEntry != nil }
        )
        XCTAssertEqual(service.updateJournal(entryID: target.id, to: "edited"), .saved)
        XCTAssertEqual(service.updateJournal(entryID: target.id, to: nil), .saved)

        XCTAssertEqual(service.calculateStreak(), streakBefore, "Streak must not move")
        XCTAssertEqual(service.fetchAllCompletions().count, totalBefore, "Total must not move")
        XCTAssertEqual(Set(badgeService.earnedBadges().map(\.badgeName)), badgesBefore,
                       "Badges must not move")
        XCTAssertTrue(service.isCompleted(on: today), "The day must still be completed")
    }
}
