import XCTest
import SwiftData
@testable import Faithfully

/// Split out of JourneyViewModelTests: editing and clearing reflections, and how
/// an active search survives a refresh, is a subject in its own right, and the
/// combined class had outgrown the length the linter enforces.
final class JourneyJournalEditTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var badgeService: BadgeService!
    var challengeService: ChallengeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        badgeService = BadgeService(modelContext: context)
        challengeService = try ChallengeService(modelContext: context, challenges: challenges, badgeService: badgeService)
    }

    // MARK: - Editing and clearing entries

    private func seedEntry(on date: Date, journal: String) throws -> UUID {
        let challenge = challengeService.challengeForDate(date)
        let completion = CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: date,
            scheduledDate: date.startOfDay,
            journalEntry: journal
        )
        context.insert(completion)
        try context.save()
        return completion.id
    }

    func testEditingAnEntryUpdatesItsTextInPlace() throws {
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "before")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.journalEntries.first?.journalText, "before")

        XCTAssertEqual(vm.updateJournal(entryID: id, to: "after"), .saved)

        XCTAssertEqual(vm.journalEntries.count, 1)
        XCTAssertEqual(vm.journalEntries.first?.journalText, "after")
    }

    func testClearingAnEntryRemovesItFromTheTimelineButNotTheTotal() throws {
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "regret this")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        let totalBefore = vm.totalCompleted

        XCTAssertEqual(vm.updateJournal(entryID: id, to: nil), .saved)

        XCTAssertTrue(vm.journalEntries.isEmpty, "A cleared entry has nothing to show")
        XCTAssertEqual(vm.totalCompleted, totalBefore,
                       "The day is still completed; only the reflection went")
    }

    func testEditingKeepsTimelineOrdering() throws {
        // Ordering is by completedDate, which an edit does not change.
        _ = try seedEntry(on: Date.from(year: 2026, month: 6, day: 10), journal: "older")
        let newerID = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "newer")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.journalEntries.map(\.journalText), ["newer", "older"])

        XCTAssertEqual(vm.updateJournal(entryID: newerID, to: "newer, revised"), .saved)

        XCTAssertEqual(vm.journalEntries.map(\.journalText), ["newer, revised", "older"])
    }

    func testAnActiveSearchSurvivesAnEdit() throws {
        _ = try seedEntry(on: Date.from(year: 2026, month: 6, day: 10), journal: "apples")
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "apples and pears")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)

        vm.searchJournal("pears")
        XCTAssertEqual(vm.journalEntries.count, 1)

        XCTAssertEqual(vm.updateJournal(entryID: id, to: "apples and pears, revised"), .saved)

        XCTAssertEqual(vm.journalEntries.count, 1,
                       "An edit must not silently drop the user back to the unfiltered list")
        XCTAssertEqual(vm.journalEntries.first?.journalText, "apples and pears, revised")
    }

    func testEditingOutOfTheActiveSearchRemovesItFromTheFilteredList() throws {
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "apples and pears")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        vm.searchJournal("pears")
        XCTAssertEqual(vm.journalEntries.count, 1)

        XCTAssertEqual(vm.updateJournal(entryID: id, to: "apples only"), .saved)

        XCTAssertTrue(vm.journalEntries.isEmpty,
                      "The entry no longer matches the query the user is looking at")
    }

    func testAFailedEditLeavesTheTimelineAlone() throws {
        let id = try seedEntry(on: Date.from(year: 2026, month: 6, day: 15), journal: "keep me")
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        let over = String(repeating: "a", count: Constants.maxJournalLength + 1)

        XCTAssertEqual(
            vm.updateJournal(entryID: id, to: over),
            .failed(.tooLong(limit: Constants.maxJournalLength,
                             actual: Constants.maxJournalLength + 1))
        )
        XCTAssertEqual(vm.journalEntries.first?.journalText, "keep me")
    }
}
