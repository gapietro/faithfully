import XCTest
import SwiftData
@testable import Faithfully

final class JourneyViewModelTests: XCTestCase {

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

    func testTotalCompletedReflectsActualCount() throws {
        let today = Date.now
        for i in 0..<5 {
            let date = today.addingDays(-i)
            let challenge = challengeService.challengeForDate(date)
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date
            )
            context.insert(completion)
        }
        try context.save()

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.totalCompleted, 5)
    }

    func testCurrentStreakReflectsCalculatedStreak() throws {
        let today = Date.now
        for i in 0..<3 {
            let date = today.addingDays(-i)
            let challenge = challengeService.challengeForDate(date)
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date
            )
            context.insert(completion)
        }
        try context.save()

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.currentStreak, 3)
    }

    func testJourneyBadgeShowsCorrectProgressTowardNextDistanceBadge() {
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        // With 0 completions, should show 5K as next badge
        XCTAssertNotNil(vm.journeyBadge)
        XCTAssertEqual(vm.journeyBadge?.definition.name, "5K")
        XCTAssertEqual(vm.journeyBadge?.current, 0)
        XCTAssertFalse(vm.journeyBadge?.isEarned ?? true)
    }

    func testAllBadgesIncludesAllEarnedAndUnearnedBadges() {
        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        let expectedCount = 5 + 5 + (10 * 4) // journey + streak + category
        XCTAssertEqual(vm.allBadges.count, expectedCount)
    }

    func testJournalEntriesLoadedInReverseChronologicalOrder() throws {
        let today = Date.now
        for i in 0..<3 {
            let date = today.addingDays(-i)
            let challenge = challengeService.challengeForDate(date)
            let completion = CompletedChallenge(
                challengeId: challenge.id,
                challengeCategory: challenge.category.rawValue,
                completedDate: date,
                scheduledDate: date,
                journalEntry: "Entry for day \(i)"
            )
            context.insert(completion)
        }
        try context.save()

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.journalEntries.count, 3)
        // First entry should be the most recent
        XCTAssertTrue(vm.journalEntries[0].date >= vm.journalEntries[1].date)
        XCTAssertTrue(vm.journalEntries[1].date >= vm.journalEntries[2].date)
    }

    func testSearchJournalFiltersByTextContent() throws {
        let today = Date.now
        let challenge1 = challengeService.challengeForDate(today)
        let challenge2 = challengeService.challengeForDate(today.addingDays(-1))

        context.insert(CompletedChallenge(
            challengeId: challenge1.id,
            challengeCategory: challenge1.category.rawValue,
            completedDate: today,
            scheduledDate: today,
            journalEntry: "God showed me grace today"
        ))
        context.insert(CompletedChallenge(
            challengeId: challenge2.id,
            challengeCategory: challenge2.category.rawValue,
            completedDate: today.addingDays(-1),
            scheduledDate: today.addingDays(-1),
            journalEntry: "Prayed for my family"
        ))
        try context.save()

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        vm.searchJournal("grace")
        XCTAssertEqual(vm.journalEntries.count, 1)
        XCTAssertTrue(vm.journalEntries[0].journalText.contains("grace"))
    }

    func testSearchJournalFiltersByChallengeTitle() throws {
        let today = Date.now
        let challenge = challengeService.challengeForDate(today)

        context.insert(CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: today,
            scheduledDate: today,
            journalEntry: "Completed this one"
        ))
        try context.save()

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        vm.searchJournal(challenge.title)
        XCTAssertEqual(vm.journalEntries.count, 1)
    }

    func testShareEntryGeneratesShareCardData() throws {
        let today = Date.now
        let challenge = challengeService.challengeForDate(today)

        context.insert(CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: today,
            scheduledDate: today,
            journalEntry: "Amazing day"
        ))
        try context.save()

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        guard let entry = vm.journalEntries.first else {
            XCTFail("No journal entry found")
            return
        }

        let card = vm.shareEntry(entry)
        XCTAssertEqual(card.title, challenge.title)
        XCTAssertEqual(card.journalText, "Amazing day")
        XCTAssertEqual(card.scriptureReference, challenge.scriptureReference)
    }

    // MARK: - No sentinel date horizon (CLEAN-009)

    private func insertCompletion(on date: Date, journal: String?) throws {
        let challenge = challengeService.challengeForDate(date)
        context.insert(CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: date,
            scheduledDate: date.startOfDay,
            journalEntry: journal
        ))
        try context.save()
    }

    func testCompletionsAfter2030AreCountedAndSearchable() throws {
        // The old fetch was bounded at 2030-12-31, so this row vanished from
        // Journey while BadgeService still counted it.
        try insertCompletion(on: Date.from(year: 2031, month: 3, day: 4), journal: "Still here in 2031")

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.totalCompleted, 1, "A post-2030 completion must count toward the total")
        XCTAssertEqual(vm.journalEntries.count, 1, "and must remain visible in the journal")

        vm.searchJournal("2031")
        XCTAssertEqual(vm.journalEntries.count, 1, "and must remain discoverable by search")
    }

    func testCompletionsBefore2020AreCountedAndSearchable() throws {
        // The lower bound was a sentinel too.
        try insertCompletion(on: Date.from(year: 2019, month: 7, day: 9), journal: "Long ago")

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.totalCompleted, 1)
        XCTAssertEqual(vm.journalEntries.count, 1)

        vm.searchJournal("Long ago")
        XCTAssertEqual(vm.journalEntries.count, 1)
    }

    func testJourneyTotalAgreesWithBadgeServiceAcrossAnyDateRange() throws {
        // The concrete inconsistency the finding describes: two components of the
        // same app reporting different totals for the same store.
        let dates = [
            Date.from(year: 2019, month: 1, day: 1),
            Date.from(year: 2026, month: 6, day: 15),
            Date.from(year: 2031, month: 12, day: 31),
            Date.from(year: 2045, month: 2, day: 2)
        ]
        for date in dates {
            try insertCompletion(on: date, journal: "entry \(date)")
        }

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        let badgeServiceTotal = badgeService.progress(for: .journey5K).current

        XCTAssertEqual(vm.totalCompleted, dates.count)
        XCTAssertEqual(vm.totalCompleted, badgeServiceTotal,
                       "Journey and BadgeService must count the same completions")
    }

    func testJournalEntriesStayInReverseChronologicalOrderAcrossTheOldHorizon() throws {
        try insertCompletion(on: Date.from(year: 2029, month: 5, day: 1), journal: "before the horizon")
        try insertCompletion(on: Date.from(year: 2033, month: 5, day: 1), journal: "after the horizon")

        let vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        XCTAssertEqual(vm.journalEntries.count, 2)
        XCTAssertEqual(vm.journalEntries.first?.journalText, "after the horizon",
                       "Ordering must span the old sentinel boundary")
        XCTAssertEqual(vm.journalEntries.last?.journalText, "before the horizon")
    }
}
