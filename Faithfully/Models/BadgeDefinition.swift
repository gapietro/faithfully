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

    /// PRD specialty ladder display names per category, ordered by tier
    /// (10 → 25 → 50 → 100). Ids stay `{category}_{beginner|devoted|warrior|master}`
    /// so previously earned badges keep resolving after a rename.
    static func specialtyNames(for category: ChallengeCategory) -> [String] {
        switch category {
        case .prayer:
            return ["Prayer Beginner", "Prayer Devoted", "Prayer Warrior", "Prayer Master"]
        case .scripture:
            return ["Scripture Beginner", "Scripture Scholar", "Scripture Warrior", "Scripture Master"]
        case .obedience:
            return ["Obedience Beginner", "Faithful Follower", "Obedience Warrior", "Obedience Master"]
        case .giving:
            return ["Giver Beginner", "Generous Heart", "Sacrificial Giver", "Cheerful Giver"]
        case .evangelism:
            return ["Witness Beginner", "Witness Devoted", "Gospel Warrior", "Gospel Master"]
        case .spiritualWarfare:
            return ["Shield Bearer", "Armor Bearer", "Battle Warrior", "Overcomer"]
        case .discipline:
            return ["Discipline Beginner", "Steadfast Disciple", "Discipline Warrior", "Discipline Master"]
        case .worshipAndThanks:
            return ["Worship Beginner", "Grateful Heart", "Worship Warrior", "Worship Master"]
        case .service:
            return ["Service Beginner", "Willing Servant", "Service Warrior", "Servant Master"]
        case .growth:
            return ["Growth Beginner", "Rooted Disciple", "Growth Warrior", "Growth Master"]
        }
    }

    static func categoryBadges(for category: ChallengeCategory) -> [BadgeDefinition] {
        let tiers: [(threshold: Int, idKey: String)] = [
            (10, "beginner"), (25, "devoted"), (50, "warrior"), (100, "master")
        ]
        let names = specialtyNames(for: category)
        return zip(tiers, names).map { tier, name in
            BadgeDefinition(
                id: "\(category.rawValue)_\(tier.idKey)",
                name: name,
                type: .category,
                category: category,
                threshold: tier.threshold
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
