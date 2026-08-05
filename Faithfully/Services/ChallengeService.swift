import Foundation
import SwiftData

enum ChallengeServiceError: Error, Equatable {
    case gracePeriodExpired
    case alreadyCompleted
    case emptyChallengePool
    case beforeEnrollment
}

protocol ChallengeServiceProtocol {
    func loadChallenges() -> [DailyChallenge]
    func challengeForDate(_ date: Date) -> DailyChallenge
    func completeChallenge(_ challenge: DailyChallenge, on scheduledDate: Date, journal: String?) throws -> [BadgeDefinition]
    func isCompleted(on scheduledDate: Date) -> Bool
    func isEligibleForCompletion(on scheduledDate: Date) -> Bool
    func fetchCompletions(for dateRange: ClosedRange<Date>) -> [CompletedChallenge]
    func calculateStreak() -> Int
}

final class ChallengeService: ChallengeServiceProtocol {
    private let modelContext: ModelContext
    private let challenges: [DailyChallenge]
    private let scheduler: ChallengeScheduler
    private let badgeService: BadgeServiceProtocol
    /// Enrollment boundary only — never feeds the schedule pairing (CLEAN-001).
    private let userStartDate: Date
    private let dateProvider: () -> Date
    private let calendar: Calendar

    /// Called after a completion is persisted, with the day that was completed
    /// and any badges the completion earned. The composition root uses this to
    /// refresh the other tabs' view models and drive notification side effects
    /// (cancel today's reminders, celebrate new badges).
    var onCompletionRecorded: ((_ scheduledDate: Date, _ newBadges: [BadgeDefinition]) -> Void)?

    init(
        modelContext: ModelContext,
        challenges: [DailyChallenge],
        badgeService: BadgeServiceProtocol,
        userStartDate: Date = .now,
        dateProvider: @escaping () -> Date = { .now },
        calendar: Calendar = .current
    ) throws {
        // Fail closed: never build a scheduler over an empty non-giving pool.
        guard let scheduler = ChallengeScheduler(challenges: challenges, calendar: calendar) else {
            throw ChallengeServiceError.emptyChallengePool
        }
        self.modelContext = modelContext
        self.challenges = challenges
        self.scheduler = scheduler
        self.badgeService = badgeService
        self.userStartDate = userStartDate
        self.dateProvider = dateProvider
        self.calendar = calendar
    }

    func loadChallenges() -> [DailyChallenge] {
        challenges
    }

    func challengeForDate(_ date: Date) -> DailyChallenge {
        // Global rotation rule (CLEAN-001): the offset counts calendar years from
        // the fixed schedule epoch, so everyone sees the same challenge on the
        // same civil date, and the pairing rotates deterministically each year.
        let offset = ChallengeScheduler.globalYearOffset(for: date, calendar: calendar)
        return scheduler.challengeForDate(date, yearOffset: offset)
    }

    /// Days before the profile's enrollment are not part of the user's journey:
    /// they can never be completed, including via grace/catch-up (CLEAN-002).
    func isEligibleForCompletion(on scheduledDate: Date) -> Bool {
        calendar.startOfDay(for: scheduledDate) >= calendar.startOfDay(for: userStartDate)
    }

    func completeChallenge(_ challenge: DailyChallenge, on scheduledDate: Date, journal: String?) throws -> [BadgeDefinition] {
        let today = dateProvider()

        // Enrollment boundary comes first so grace-window math can never
        // resurrect a day that predates the user's journey (CLEAN-002).
        guard isEligibleForCompletion(on: scheduledDate) else {
            throw ChallengeServiceError.beforeEnrollment
        }

        guard GracePeriod.canComplete(challengeDate: scheduledDate, today: today) else {
            throw ChallengeServiceError.gracePeriodExpired
        }

        // Completion identity is the scheduled calendar day, not the challenge ID:
        // the scheduler reuses IDs within a year, so keying by ID would wrongly
        // block (or mark done) a later day that reuses the same challenge.
        guard !isCompleted(on: scheduledDate) else {
            throw ChallengeServiceError.alreadyCompleted
        }

        let trimmedJournal = journal?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalJournal = trimmedJournal.flatMap { $0.isEmpty ? nil : String($0.prefix(Constants.maxJournalLength)) }

        let completion = CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: today,
            scheduledDate: scheduledDate.startOfDay,
            journalEntry: finalJournal
        )

        modelContext.insert(completion)
        try modelContext.save()

        let newBadges = badgeService.evaluateAndAward()
        onCompletionRecorded?(scheduledDate, newBadges)
        return newBadges
    }

    func isCompleted(on scheduledDate: Date) -> Bool {
        let dayStart = scheduledDate.startOfDay
        let dayEnd = dayStart.addingDays(1)
        let descriptor = FetchDescriptor<CompletedChallenge>(
            predicate: #Predicate { $0.scheduledDate >= dayStart && $0.scheduledDate < dayEnd }
        )
        let results = (try? modelContext.fetch(descriptor)) ?? []
        return !results.isEmpty
    }

    func fetchCompletions(for dateRange: ClosedRange<Date>) -> [CompletedChallenge] {
        let start = dateRange.lowerBound
        let end = dateRange.upperBound
        let descriptor = FetchDescriptor<CompletedChallenge>(
            predicate: #Predicate { $0.scheduledDate >= start && $0.scheduledDate <= end }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    func calculateStreak() -> Int {
        let descriptor = FetchDescriptor<CompletedChallenge>()
        let completions = (try? modelContext.fetch(descriptor)) ?? []
        let dates = completions.map(\.scheduledDate)
        return StreakCalculator.calculateStreak(completionDates: dates, today: dateProvider())
    }
}
