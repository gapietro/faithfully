import Foundation

struct BadgeDisplayItem: Identifiable, Equatable {
    let id: String
    let name: String
    let type: BadgeType
    let category: ChallengeCategory?
    let threshold: Int
    let current: Int
    let isEarned: Bool
    let earnedDate: Date?

    var progress: Double {
        guard threshold > 0 else { return 1.0 }
        return min(Double(current) / Double(threshold), 1.0)
    }
}
