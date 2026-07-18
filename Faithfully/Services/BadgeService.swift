import Foundation
import SwiftData

protocol BadgeServiceProtocol {
    @discardableResult
    func evaluateAndAward() -> [BadgeDefinition]
    func allBadgeDefinitions() -> [BadgeDefinition]
    func progress(for badge: BadgeDefinition) -> BadgeProgress
    func earnedBadges() -> [EarnedBadge]
}

final class BadgeService: BadgeServiceProtocol {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func evaluateAndAward() -> [BadgeDefinition] {
        let completions = fetchAllCompletions()
        let totalCompleted = completions.count

        // Calculate streak from scheduled dates
        let scheduledDates = completions.map(\.scheduledDate)
        let currentStreak = StreakCalculator.calculateStreak(completionDates: scheduledDates)

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
            modelContext.insert(earnedBadge)
        }

        if !newBadges.isEmpty {
            try? modelContext.save()
        }

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
            let dates = completions.map(\.scheduledDate)
            current = StreakCalculator.calculateStreak(completionDates: dates)
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

    func earnedBadges() -> [EarnedBadge] {
        let descriptor = FetchDescriptor<EarnedBadge>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func fetchAllCompletions() -> [CompletedChallenge] {
        let descriptor = FetchDescriptor<CompletedChallenge>()
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
