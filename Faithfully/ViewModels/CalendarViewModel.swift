import Foundation
import SwiftData
import Observation

@Observable
final class CalendarViewModel {
    var calendarDays: [CalendarDay] = []
    var selectedDay: CalendarDay?
    var currentMonth: Date

    private let challengeService: ChallengeServiceProtocol
    private let today: Date

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

    func selectDay(_ day: CalendarDay) {
        selectedDay = day
    }

    func completeGracePeriod(_ day: CalendarDay, journal: String? = nil) {
        guard let challenge = day.challenge else { return }
        do {
            _ = try challengeService.completeChallenge(challenge, on: day.date, journal: journal)
            loadMonth()
        } catch {
            // Grace period expired or already completed
        }
    }

    func loadMonth() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: startOfMonth),
              let endOfMonth = calendar.date(byAdding: .day, value: range.count - 1, to: startOfMonth) else { return }

        let todayStart = calendar.startOfDay(for: today)

        // Completion truth is keyed by scheduled calendar day, not challenge ID —
        // the scheduler reuses IDs within a year, so an ID lookup would mark
        // unrelated days as done. Fetch past end-of-day so late-day timestamps match.
        let completions = challengeService.fetchCompletions(for: startOfMonth...endOfMonth.addingDays(1))
        let completedDays = Set(completions.map { calendar.startOfDay(for: $0.scheduledDate) })
        let journalByDay = Dictionary(
            completions.compactMap { c in
                c.journalEntry.map { (calendar.startOfDay(for: c.scheduledDate), $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )

        calendarDays = range.compactMap { dayNumber in
            guard let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: startOfMonth) else { return nil }
            let dateStart = calendar.startOfDay(for: date)
            let challenge = challengeService.challengeForDate(date)
            let isCompleted = completedDays.contains(dateStart)

            let status: CalendarDayStatus
            if dateStart > todayStart {
                status = .future
            } else if isCompleted {
                status = .completed
            } else if GracePeriod.canComplete(challengeDate: date, today: today) {
                status = .missedRecoverable
            } else {
                status = .missed
            }

            return CalendarDay(
                date: date,
                challenge: challenge,
                status: status,
                journalEntry: journalByDay[dateStart]
            )
        }
    }
}
