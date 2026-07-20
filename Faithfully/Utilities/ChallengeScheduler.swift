import Foundation

struct ChallengeScheduler {
    private let givingChallenges: [DailyChallenge]
    private let nonGivingChallenges: [DailyChallenge]

    /// Fails when the non-giving pool is empty: every non-first-Saturday day draws
    /// from that pool, so an empty pool would mean modulo-by-zero and no challenge
    /// to show. Callers must fail closed instead of constructing a broken scheduler.
    init?(challenges: [DailyChallenge]) {
        let nonGiving = challenges.filter { $0.category != .giving }
        guard !nonGiving.isEmpty else { return nil }
        self.givingChallenges = challenges.filter { $0.category == .giving }
        self.nonGivingChallenges = nonGiving
    }

    func challengeForDate(_ date: Date, yearOffset: Int = 0) -> DailyChallenge {
        if isFirstSaturdayOfMonth(date) && !givingChallenges.isEmpty {
            let monthIndex = Calendar.current.component(.month, from: date) - 1
            let givingIndex = (monthIndex + yearOffset) % givingChallenges.count
            return givingChallenges[abs(givingIndex) % givingChallenges.count]
        }

        let dayOfYear = min(Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1, 365)
        let index = (dayOfYear + (yearOffset * 47)) % nonGivingChallenges.count
        let safeIndex = ((index % nonGivingChallenges.count) + nonGivingChallenges.count) % nonGivingChallenges.count
        return nonGivingChallenges[safeIndex]
    }

    func isFirstSaturdayOfMonth(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let day = calendar.component(.day, from: date)
        return weekday == 7 && day <= 7 // Saturday = 7 in Calendar
    }

    static func yearOffset(from startDate: Date, to date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: startDate, to: date).year ?? 0
    }
}
