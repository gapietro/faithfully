import Foundation

struct GracePeriod {
    static let maxGraceDays = 3

    static func canComplete(challengeDate: Date, today: Date = .now) -> Bool {
        let calendar = Calendar.current
        let challengeStart = calendar.startOfDay(for: challengeDate)
        let todayStart = calendar.startOfDay(for: today)

        guard let daysDifference = calendar.dateComponents([.day], from: challengeStart, to: todayStart).day else {
            return false
        }

        // Can complete today's challenge or challenges from the last 3 days
        // Cannot complete future challenges
        return daysDifference >= 0 && daysDifference <= maxGraceDays
    }
}
