import Foundation

struct ChallengeScheduler {
    /// Global schedule epoch: year offsets count calendar years since 2025, so
    /// every user shares the same challenge on the same civil date regardless of
    /// when they installed the app (CLEAN-001). Rotation is a pure function of
    /// the civil date, never of enrollment.
    static let scheduleEpochYear = 2025

    private let givingChallenges: [DailyChallenge]
    private let nonGivingChallenges: [DailyChallenge]
    private let calendar: Calendar

    /// Fails when the non-giving pool is empty: every non-first-Saturday day draws
    /// from that pool, so an empty pool would mean modulo-by-zero and no challenge
    /// to show. Callers must fail closed instead of constructing a broken scheduler.
    init?(challenges: [DailyChallenge], calendar: Calendar = .current) {
        let nonGiving = challenges.filter { $0.category != .giving }
        guard !nonGiving.isEmpty else { return nil }
        self.givingChallenges = challenges.filter { $0.category == .giving }
        self.nonGivingChallenges = nonGiving
        self.calendar = calendar
    }

    func challengeForDate(_ date: Date, yearOffset: Int = 0) -> DailyChallenge {
        if isFirstSaturdayOfMonth(date) && !givingChallenges.isEmpty {
            let monthIndex = calendar.component(.month, from: date) - 1
            let givingIndex = (monthIndex + yearOffset) % givingChallenges.count
            return givingChallenges[abs(givingIndex) % givingChallenges.count]
        }

        let dayOfYear = min(calendar.ordinality(of: .day, in: .year, for: date) ?? 1, 365)
        let index = (dayOfYear + (yearOffset * 47)) % nonGivingChallenges.count
        let safeIndex = ((index % nonGivingChallenges.count) + nonGivingChallenges.count) % nonGivingChallenges.count
        return nonGivingChallenges[safeIndex]
    }

    func isFirstSaturdayOfMonth(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        let day = calendar.component(.day, from: date)
        return weekday == 7 && day <= 7 // Saturday = 7 in Calendar
    }

    /// Year offset for the global rotation (CLEAN-001): calendar years between
    /// `date` and the fixed epoch. Depends only on the civil date, so two users
    /// enrolled years apart still get identical pairings on the same day.
    static func globalYearOffset(for date: Date, calendar: Calendar = .current) -> Int {
        calendar.component(.year, from: date) - scheduleEpochYear
    }
}
