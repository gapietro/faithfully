import Foundation

struct BadgeDefinition: Identifiable, Equatable {
    let id: String
    let name: String
    let type: BadgeType
    let category: ChallengeCategory?
    let threshold: Int

    // MARK: - Journey Badges

    static let journey5K = BadgeDefinition(id: "journey_5k", name: "5K", type: .journey, category: nil, threshold: 31)
    static let journey10K = BadgeDefinition(id: "journey_10k", name: "10K", type: .journey, category: nil, threshold: 90)
    static let journeyHalfMarathon = BadgeDefinition(id: "journey_half", name: "Half Marathon", type: .journey, category: nil, threshold: 182)
    static let journeyMarathon = BadgeDefinition(id: "journey_marathon", name: "Marathon", type: .journey, category: nil, threshold: 365)
    static let journeyUltra = BadgeDefinition(id: "journey_ultra", name: "Ultra", type: .journey, category: nil, threshold: 730)

    static let allJourneyBadges: [BadgeDefinition] = [
        journey5K, journey10K, journeyHalfMarathon, journeyMarathon, journeyUltra
    ]

    // MARK: - Streak Badges

    static let streakEmber = BadgeDefinition(id: "streak_ember", name: "Ember", type: .streak, category: nil, threshold: 7)
    static let streakFlame = BadgeDefinition(id: "streak_flame", name: "Flame", type: .streak, category: nil, threshold: 30)
    static let streakFire = BadgeDefinition(id: "streak_fire", name: "Fire", type: .streak, category: nil, threshold: 90)
    static let streakFurnace = BadgeDefinition(id: "streak_furnace", name: "Furnace", type: .streak, category: nil, threshold: 180)
    static let streakUnquenchable = BadgeDefinition(id: "streak_unquenchable", name: "Unquenchable", type: .streak, category: nil, threshold: 365)

    static let allStreakBadges: [BadgeDefinition] = [
        streakEmber, streakFlame, streakFire, streakFurnace, streakUnquenchable
    ]

    // MARK: - Category Badges

    static func categoryBadges(for category: ChallengeCategory) -> [BadgeDefinition] {
        let levels: [(Int, String)] = [(10, "Beginner"), (25, "Devoted"), (50, "Warrior"), (100, "Master")]
        return levels.map { threshold, level in
            BadgeDefinition(
                id: "\(category.rawValue)_\(level.lowercased())",
                name: "\(category.displayName) \(level)",
                type: .category,
                category: category,
                threshold: threshold
            )
        }
    }

    static let allCategoryBadges: [BadgeDefinition] = {
        ChallengeCategory.allCases.flatMap { categoryBadges(for: $0) }
    }()

    // MARK: - All Badges

    static let allBadges: [BadgeDefinition] = {
        allJourneyBadges + allStreakBadges + allCategoryBadges
    }()
}
