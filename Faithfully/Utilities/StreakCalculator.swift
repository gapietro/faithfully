import Foundation

struct StreakCalculator {
    /// Counts consecutive completed civil days ending today (or yesterday, when
    /// today is not yet done).
    ///
    /// Operates on frozen `CivilDay` keys rather than on stored instants. The
    /// previous version mapped `[Date]` through `Calendar.current.startOfDay`
    /// on every call, so the same completions could group into different days
    /// after a time-zone change and a streak the user had genuinely earned would
    /// appear to break.
    ///
    /// Stepping backwards goes through the calendar, not through subtraction of
    /// 86,400 seconds: a DST day is 23 or 25 hours long, and second-arithmetic
    /// skips or repeats a day twice a year.
    static func calculateStreak(completedDayKeys: [Int], today: Date = .now) -> Int {
        let completed = Set(completedDayKeys)
        guard !completed.isEmpty else { return 0 }

        let todayKey = CivilDay.key(for: today)
        var checkKey = todayKey

        // Today not yet completed is not a broken streak — the day isn't over.
        if !completed.contains(checkKey) {
            guard let yesterday = CivilDay.key(todayKey, offsetByDays: -1) else { return 0 }
            checkKey = yesterday
        }

        var streak = 0
        while completed.contains(checkKey) {
            streak += 1
            guard let previous = CivilDay.key(checkKey, offsetByDays: -1) else { break }
            checkKey = previous
        }
        return streak
    }

    /// Convenience for callers holding instants rather than keys, such as tests
    /// constructing a scenario. Production paths read `dayKey` directly.
    static func calculateStreak(completionDates: [Date], today: Date = .now) -> Int {
        calculateStreak(completedDayKeys: completionDates.map { CivilDay.key(for: $0) }, today: today)
    }
}
