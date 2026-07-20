import XCTest
import SwiftData
@testable import Faithfully

final class DailyWalkViewModelTests: XCTestCase {

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

    func testInitLoadsTodaysChallenge() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        let expected = challengeService.challengeForDate(today)
        XCTAssertEqual(vm.todayChallenge.id, expected.id)
    }

    func testIsCompletedReflectsActualCompletionState() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        XCTAssertFalse(vm.isCompleted)
    }

    func testCurrentStreakReflectsCalculatedStreak() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        XCTAssertEqual(vm.currentStreak, 0)
    }

    func testCompleteCallsChallengeServiceCompleteChallenge() throws {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)

        // Verify completion was persisted
        let descriptor = FetchDescriptor<CompletedChallenge>()
        let completions = try context.fetch(descriptor)
        XCTAssertEqual(completions.count, 1)
    }

    func testCompleteUpdatesIsCompletedToTrue() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertTrue(vm.isCompleted)
    }

    func testCompleteUpdatesCurrentStreak() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertEqual(vm.currentStreak, 1)
    }

    func testCompleteSetsNewBadgesIfBadgesAwarded() throws {
        let today = Date.now
        // Insert 30 prior completions so the 31st triggers 5K badge
        for i in 1...30 {
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

        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertFalse(vm.newBadges.isEmpty, "Should have new badges after 31 completions")
    }

    func testCompleteSetsShowCelebrationIfBadgesAwarded() throws {
        let today = Date.now
        for i in 1...30 {
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

        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        vm.complete(journal: nil)
        XCTAssertTrue(vm.showCelebration)
    }

    func testTranslationChangeUpdatesScriptureText() {
        let today = Date.now
        let vm = DailyWalkViewModel(challengeService: challengeService, today: today)
        let esvText = vm.scriptureText
        XCTAssertEqual(esvText, vm.todayChallenge.scriptureText(for: .esv))

        vm.updateTranslation(.niv)
        XCTAssertEqual(vm.scriptureText, vm.todayChallenge.scriptureText(for: .niv))
        XCTAssertEqual(vm.translation, .niv)
    }
}
