import Foundation

struct CompletionResult {
    let completion: CompletedChallenge
    let newBadges: [EarnedBadge]
    let currentStreak: Int
    let totalCompleted: Int
}
