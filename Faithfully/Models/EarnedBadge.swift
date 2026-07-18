import Foundation
import SwiftData

@Model
final class EarnedBadge {
    var id: UUID
    var badgeName: String
    var badgeType: BadgeType
    var category: ChallengeCategory?
    var threshold: Int
    var earnedDate: Date

    init(
        id: UUID = UUID(),
        badgeName: String,
        badgeType: BadgeType,
        category: ChallengeCategory? = nil,
        threshold: Int,
        earnedDate: Date = .now
    ) {
        self.id = id
        self.badgeName = badgeName
        self.badgeType = badgeType
        self.category = category
        self.threshold = threshold
        self.earnedDate = earnedDate
    }
}
