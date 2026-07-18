import Foundation

struct StreakCalculator {
    static func calculateStreak(completionDates: [Date], today: Date = .now) -> Int {
        let calendar = Calendar.current

        let uniqueDates = Set(completionDates.map { calendar.startOfDay(for: $0) })

        if uniqueDates.isEmpty {
            return 0
        }

        var streak = 0
        var checkDate = calendar.startOfDay(for: today)

        // If today is not completed, start checking from yesterday
        if !uniqueDates.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                return 0
            }
            checkDate = yesterday
        }

        // Count backwards through consecutive days
        while uniqueDates.contains(checkDate) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                break
            }
            checkDate = previousDay
        }

        return streak
    }
}
