import Foundation

struct BadgeProgress: Equatable {
    let definition: BadgeDefinition
    let current: Int
    let isEarned: Bool
    let earnedDate: Date?

    var progress: Double {
        guard definition.threshold > 0 else { return 1.0 }
        return min(Double(current) / Double(definition.threshold), 1.0)
    }
}
