import Foundation

struct BadgeEvaluator {
    static func evaluate(
        totalCompleted: Int,
        currentStreak: Int,
        categoryCounts: [ChallengeCategory: Int],
        earnedBadgeNames: Set<String>
    ) -> [BadgeDefinition] {
        var newBadges: [BadgeDefinition] = []

        // Journey badges
        for badge in BadgeDefinition.allJourneyBadges {
            if totalCompleted >= badge.threshold && !earnedBadgeNames.contains(badge.id) {
                newBadges.append(badge)
            }
        }

        // Streak badges
        for badge in BadgeDefinition.allStreakBadges {
            if currentStreak >= badge.threshold && !earnedBadgeNames.contains(badge.id) {
                newBadges.append(badge)
            }
        }

        // Category badges
        for category in ChallengeCategory.allCases {
            let count = categoryCounts[category] ?? 0
            for badge in BadgeDefinition.categoryBadges(for: category) {
                if count >= badge.threshold && !earnedBadgeNames.contains(badge.id) {
                    newBadges.append(badge)
                }
            }
        }

        return newBadges
    }
}
