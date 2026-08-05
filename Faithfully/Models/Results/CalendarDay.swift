import Foundation

enum CalendarDayStatus: Equatable {
    case completed
    case missed
    case missedRecoverable
    case future
    case today
    /// Pre-enrollment: the day predates the user's journey and was never
    /// missable, so it renders as not-applicable rather than missed (CLEAN-002).
    case unavailable
}

struct CalendarDay: Identifiable, Equatable {
    let id: Date
    let date: Date
    let challenge: DailyChallenge?
    let status: CalendarDayStatus
    let journalEntry: String?

    init(date: Date, challenge: DailyChallenge? = nil, status: CalendarDayStatus, journalEntry: String? = nil) {
        self.id = date
        self.date = date
        self.challenge = challenge
        self.status = status
        self.journalEntry = journalEntry
    }

    static func == (lhs: CalendarDay, rhs: CalendarDay) -> Bool {
        lhs.date == rhs.date && lhs.status == rhs.status
    }
}
