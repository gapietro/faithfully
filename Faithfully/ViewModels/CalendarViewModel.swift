import Foundation
import SwiftData
import Observation

@Observable
final class CalendarViewModel {
    var calendarDays: [CalendarDay] = []
    var selectedDay: CalendarDay?
    var currentMonth: Date

    private let challengeService: ChallengeServiceProtocol
    private var today: Date

    /// Fired after a journal edit made *by this view model* is saved, so
    /// `AppServices` can catch up the other tabs. Never invoked for an edit
    /// this view model did not originate, and never for a failed one.
    var onJournalChanged: (() -> Void)?

    init(challengeService: ChallengeServiceProtocol, today: Date = .now) {
        self.challengeService = challengeService
        self.today = today
        self.currentMonth = today
        loadMonth()
    }

    func nextMonth() {
        guard let next = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) else { return }
        currentMonth = next
        loadMonth()
    }

    func previousMonth() {
        guard let prev = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) else { return }
        currentMonth = prev
        loadMonth()
    }

    /// Rolls the calendar to the current day: if the day changed while the app
    /// stayed in memory, the today/future boundary and grace windows must be
    /// re-evaluated against the new day. Follows a month rollover only when the
    /// user was viewing the current month, preserving their browsing position.
    func refresh(for newToday: Date) {
        let calendar = Calendar.current
        if !calendar.isDate(newToday, inSameDayAs: today) {
            if calendar.isDate(currentMonth, equalTo: today, toGranularity: .month) {
                currentMonth = newToday
            }
            today = newToday
        }
        loadMonth()
        // An open day detail must reflect the rebuilt truth: re-bind the
        // selection to the same date's new CalendarDay (status and grace
        // window may have changed), or drop it if the day left the grid.
        rebindSelectedDay()
    }

    func selectDay(_ day: CalendarDay) {
        selectedDay = day
    }

    func completeGracePeriod(_ day: CalendarDay, journal: String? = nil) {
        guard let challenge = day.challenge else { return }
        // Defence in depth: the detail view already hides Complete for these,
        // but a stale selection must not be able to reach the service.
        guard day.status == .missedRecoverable || day.status == .today else { return }
        do {
            _ = try challengeService.completeChallenge(challenge, on: day.date, journal: journal)
            loadMonth()
        } catch {
            // Grace period expired or already completed
        }
    }

    /// Edits or clears the reflection on a day, then rebuilds the grid.
    ///
    /// Returns the result rather than swallowing it: the caller owns the editor
    /// and the user's text, and must keep both unless this says `.saved`.
    @discardableResult
    func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult {
        let result = challengeService.updateJournal(entryID: entryID, to: text)
        guard result.isSaved else { return result }

        loadMonth()
        // Re-bind any open detail panel to the rebuilt day, so it shows the new
        // text rather than the value it was constructed with.
        rebindSelectedDay()
        // Only after a successful save, and only for an edit this view model
        // made itself — `refreshJournal()` is the entry point for catching up
        // on an edit made elsewhere, so calling this callback from there too
        // would recurse.
        onJournalChanged?()
        return result
    }

    /// Cross-tab catch-up: rebuilds the grid and any open day detail after a
    /// journal edit made through Journey, the timeline this view model doesn't
    /// own. Kept separate from `updateJournal` so this view model never
    /// re-enters its own edit and never re-fires `onJournalChanged`.
    func refreshJournal() {
        loadMonth()
        rebindSelectedDay()
    }

    /// Re-binds the open day detail, if any, to its rebuilt `CalendarDay` — a
    /// value type, so the panel otherwise keeps showing whatever it was
    /// constructed with even after the underlying data changes.
    private func rebindSelectedDay() {
        guard let selected = selectedDay else { return }
        selectedDay = calendarDays.first {
            Calendar.current.isDate($0.date, inSameDayAs: selected.date)
        }
    }

    func loadMonth() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth),
              let endOfMonth = calendar.date(byAdding: .day, value: range.count - 1, to: startOfMonth) else { return }

        let todayStart = calendar.startOfDay(for: today)
        let enrollmentStart = calendar.startOfDay(for: challengeService.enrollmentDate)

        // Completion truth is keyed by civil day, not challenge ID — the
        // scheduler reuses IDs within a year, so an ID lookup would mark
        // unrelated days as done. Keys are frozen at write time, so no
        // end-of-day padding is needed and no row can drift out of the month.
        let completions = challengeService.fetchCompletions(for: startOfMonth...endOfMonth)
        let completedDays = Set(completions.map(\.dayKey))
        let journalByDay = Dictionary(
            completions.compactMap { completion in
                completion.journalEntry.map { (completion.dayKey, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        // Keyed for every completion, not only those with text: a day completed
        // without a reflection still needs to be addressable so one can be added.
        let completionIDByDay = Dictionary(
            completions.map { ($0.dayKey, $0.id) },
            uniquingKeysWith: { first, _ in first }
        )

        calendarDays = range.compactMap { dayNumber in
            guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: startOfMonth) else { return nil }
            let dateStart = calendar.startOfDay(for: date)
            let dayKey = CivilDay.key(for: date, calendar: calendar)
            let challenge = challengeService.challengeForDate(date)
            let isCompleted = completedDays.contains(dayKey)

            // Precedence: a completed today shows completed; an incomplete
            // today shows .today (distinguishable per PRD), not the grace
            // styling that raw GracePeriod math would give it. Days before
            // enrollment are neither missed nor recoverable — a brand-new user
            // must not open the calendar to a wall of failures they never had
            // the chance to attempt.
            let status: CalendarDayStatus
            if dateStart > todayStart {
                status = .future
            } else if dateStart < enrollmentStart {
                status = .preEnrollment
            } else if isCompleted {
                status = .completed
            } else if dateStart == todayStart {
                status = .today
            } else if GracePeriod.canComplete(challengeDate: date, today: today) {
                status = .missedRecoverable
            } else {
                status = .missed
            }

            return CalendarDay(
                date: date,
                challenge: challenge,
                status: status,
                journalEntry: journalByDay[dayKey],
                completionID: completionIDByDay[dayKey]
            )
        }
    }
}
