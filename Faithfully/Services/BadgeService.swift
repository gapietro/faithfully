import Foundation
import SwiftData

protocol BadgeServiceProtocol {
    /// Inserts any newly earned badges into the context **without saving**, and
    /// returns them. The caller commits, so a completion and the badges it earns
    /// land in one transaction instead of two independent ones.
    @discardableResult
    func evaluateAndStageAwards() -> [BadgeDefinition]
    func allBadgeDefinitions() -> [BadgeDefinition]
    func progress(for badge: BadgeDefinition) -> BadgeProgress
    func earnedBadges() -> [EarnedBadge]
}

final class BadgeService: BadgeServiceProtocol {
    private let persistence: PersistenceCoordinating

    init(persistence: PersistenceCoordinating) {
        self.persistence = persistence
    }

    convenience init(modelContext: ModelContext) {
        self.init(persistence: PersistenceCoordinator(context: modelContext))
    }

    func evaluateAndStageAwards() -> [BadgeDefinition] {
        let completions = fetchAllCompletions()
        let totalCompleted = completions.count

        // Streak from frozen civil days, never from re-read instants.
        let currentStreak = StreakCalculator.calculateStreak(completedDayKeys: completions.map(\.dayKey))

        // Count per category
        var categoryCounts: [ChallengeCategory: Int] = [:]
        for completion in completions {
            if let cat = ChallengeCategory(rawValue: completion.challengeCategory) {
                categoryCounts[cat, default: 0] += 1
            }
        }

        // Get already earned badge IDs
        let earned = earnedBadges()
        let earnedNames = Set(earned.map(\.badgeName))

        let newBadges = BadgeEvaluator.evaluate(
            totalCompleted: totalCompleted,
            currentStreak: currentStreak,
            categoryCounts: categoryCounts,
            earnedBadgeNames: earnedNames
        )

        // Persist new badges
        for badge in newBadges {
            let earnedBadge = EarnedBadge(
                badgeName: badge.id,
                badgeType: badge.type,
                category: badge.category,
                threshold: badge.threshold
            )
            persistence.insert(earnedBadge)
        }

        // Deliberately no save here: the caller owns the transaction boundary.
        return newBadges
    }

    func allBadgeDefinitions() -> [BadgeDefinition] {
        BadgeDefinition.allBadges
    }

    func progress(for badge: BadgeDefinition) -> BadgeProgress {
        let completions = fetchAllCompletions()
        let earned = earnedBadges()
        let isEarned = earned.contains { $0.badgeName == badge.id }
        let earnedDate = earned.first { $0.badgeName == badge.id }?.earnedDate

        let current: Int
        switch badge.type {
        case .journey:
            current = completions.count
        case .streak:
            current = StreakCalculator.calculateStreak(completedDayKeys: completions.map(\.dayKey))
        case .category:
            if let cat = badge.category {
                current = completions.filter { $0.challengeCategory == cat.rawValue }.count
            } else {
                current = 0
            }
        }

        return BadgeProgress(
            definition: badge,
            current: current,
            isEarned: isEarned,
            earnedDate: earnedDate
        )
    }

    // Reads stay lenient: a failed read degrades a progress bar, while a failed
    // *write* silently loses user data. Only writes are made to throw.
    func earnedBadges() -> [EarnedBadge] {
        (try? persistence.fetch(FetchDescriptor<EarnedBadge>())) ?? []
    }

    private func fetchAllCompletions() -> [CompletedChallenge] {
        (try? persistence.fetch(FetchDescriptor<CompletedChallenge>())) ?? []
    }
}
