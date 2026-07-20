import Foundation
import SwiftData
import Observation

@Observable
final class DailyWalkViewModel {
    var todayChallenge: DailyChallenge
    var isCompleted: Bool = false
    var currentStreak: Int = 0
    var showCelebration: Bool = false
    var newBadges: [BadgeDefinition] = []
    var translation: BibleTranslation = .esv

    let yesterdayChallenge: DailyChallenge

    private let challengeService: ChallengeServiceProtocol
    private let today: Date

    var scriptureText: String {
        todayChallenge.scriptureText(for: translation)
    }

    init(challengeService: ChallengeServiceProtocol, today: Date = .now) {
        self.challengeService = challengeService
        self.today = today
        self.todayChallenge = challengeService.challengeForDate(today)
        self.yesterdayChallenge = challengeService.challengeForDate(today.addingDays(-1))
        self.isCompleted = challengeService.isCompleted(on: today)
        self.currentStreak = challengeService.calculateStreak()
    }

    func refresh() {
        isCompleted = challengeService.isCompleted(on: today)
        currentStreak = challengeService.calculateStreak()
    }

    func complete(journal: String? = nil) {
        guard !isCompleted else { return }
        do {
            let badges = try challengeService.completeChallenge(todayChallenge, on: today, journal: journal)
            isCompleted = true
            currentStreak = challengeService.calculateStreak()
            if !badges.isEmpty {
                newBadges = badges
                showCelebration = true
            }
        } catch {
            // Completion failed (grace period expired or already completed)
        }
    }

    func updateTranslation(_ newTranslation: BibleTranslation) {
        translation = newTranslation
    }
}
