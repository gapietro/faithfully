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
}
