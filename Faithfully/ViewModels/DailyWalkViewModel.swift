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
    var translation: BibleTranslation = .web

    private(set) var yesterdayChallenge: DailyChallenge

    private let challengeService: ChallengeServiceProtocol
    private var today: Date

    var scriptureText: String {
        todayChallenge.scriptureText(for: translation)
    }

    init(challengeService: ChallengeServiceProtocol, today: Date = .now, translation: BibleTranslation = .web) {
        self.challengeService = challengeService
        self.today = today
        self.translation = translation
        self.todayChallenge = challengeService.challengeForDate(today)
        self.yesterdayChallenge = challengeService.challengeForDate(today.addingDays(-1))
        self.isCompleted = challengeService.isCompleted(on: today)
        self.currentStreak = challengeService.calculateStreak()
    }

    func refresh() {
        isCompleted = challengeService.isCompleted(on: today)
        currentStreak = challengeService.calculateStreak()
    }

    /// Rolls the view model to the current day: if the calendar day changed while
    /// the app stayed in memory (foregrounded after midnight), the challenge and
    /// completed state must be the new day's, not the day the app launched on.
    func refresh(for newToday: Date) {
        if !Calendar.current.isDate(newToday, inSameDayAs: today) {
            today = newToday
            todayChallenge = challengeService.challengeForDate(newToday)
            yesterdayChallenge = challengeService.challengeForDate(newToday.addingDays(-1))
            // A celebration left showing overnight belongs to the previous day's
            // completion; carrying it into the new day blocks the fresh UI.
            showCelebration = false
            newBadges = []
        }
        refresh()
    }

    /// Reports the outcome instead of swallowing it. The caller owns the editor
    /// and the user's draft, and must keep both until it sees `.completed` —
    /// otherwise a rejected or failed save silently destroys the reflection.
    @discardableResult
    func complete(journal: String? = nil) -> CompletionResult {
        guard !isCompleted else { return .failed(.alreadyCompleted) }
        do {
            let badges = try challengeService.completeChallenge(todayChallenge, on: today, journal: journal)
            isCompleted = true
            currentStreak = challengeService.calculateStreak()
            if !badges.isEmpty {
                newBadges = badges
                showCelebration = true
            }
            return .completed(newBadges: badges)
        } catch let error as ChallengeServiceError {
            return .failed(CompletionFailure(error))
        } catch {
            // Anything else is a persistence failure: the draft is still the only
            // copy of what the user wrote, so say so rather than implying success.
            return .failed(.couldNotSave)
        }
    }

    func updateTranslation(_ newTranslation: BibleTranslation) {
        translation = newTranslation
    }
}
