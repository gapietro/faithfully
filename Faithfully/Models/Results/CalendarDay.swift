import Foundation

enum CalendarDayStatus: Equatable {
    case completed
    case missed
    case missedRecoverable
    case future
    /// Before the user enrolled. Distinct from `.missed`: the user did not fail
    /// to do these days, they simply were not here for them, so the calendar must
    /// not show them as a deficit and they can never be completed.
    case preEnrollment
    case today

    /// Spoken by VoiceOver and asserted by the UI tests.
    ///
    /// Status is otherwise conveyed only by colour, which is both inaccessible
    /// and untestable — a UI test can see that a day exists but not that it is
    /// green. Exposing it as an accessibility value fixes both at once.
    var accessibilityDescription: String {
        switch self {
        case .completed: return "Completed"
        case .missed: return "Missed"
        case .missedRecoverable: return "Missed, can still be completed"
        case .future: return "Upcoming"
        case .preEnrollment: return "Before you started"
        case .today: return "Today, not yet completed"
        }
    }
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
