import Foundation
import SwiftData

enum ChallengeServiceError: Error {
    case gracePeriodExpired
    case alreadyCompleted
    case emptyChallengePool
    case beforeEnrollment
}

protocol ChallengeServiceProtocol {
    /// The first day this user is eligible to complete. Earlier days are not
    /// missed days — they are not this user's days at all, and no completion,
    /// streak, or badge credit may be earned for them.
    var enrollmentDate: Date { get }

    func loadChallenges() -> [DailyChallenge]
    func challengeForDate(_ date: Date) -> DailyChallenge
    func completeChallenge(_ challenge: DailyChallenge, on scheduledDate: Date, journal: String?) throws -> [BadgeDefinition]
    func isCompleted(on scheduledDate: Date) -> Bool
    func fetchCompletions(for dateRange: ClosedRange<Date>) -> [CompletedChallenge]
    func calculateStreak() -> Int
}

final class ChallengeService: ChallengeServiceProtocol {
    private let modelContext: ModelContext
    private let challenges: [DailyChallenge]
    private let scheduler: ChallengeScheduler
    private let badgeService: BadgeServiceProtocol
    let enrollmentDate: Date
    private let dateProvider: () -> Date

    /// Called after a completion is persisted, with the day that was completed
    /// and any badges the completion earned. The composition root uses this to
    /// refresh the other tabs' view models and drive notification side effects
    /// (cancel today's reminders, celebrate new badges).
    var onCompletionRecorded: ((_ scheduledDate: Date, _ newBadges: [BadgeDefinition]) -> Void)?

    init(
        modelContext: ModelContext,
        challenges: [DailyChallenge],
        badgeService: BadgeServiceProtocol,
        enrollmentDate: Date = .now,
        dateProvider: @escaping () -> Date = { .now }
    ) throws {
        // Fail closed: never build a scheduler over an empty non-giving pool.
        guard let scheduler = ChallengeScheduler(challenges: challenges) else {
            throw ChallengeServiceError.emptyChallengePool
        }
        self.modelContext = modelContext
        self.challenges = challenges
        self.scheduler = scheduler
        self.badgeService = badgeService
        self.enrollmentDate = enrollmentDate
        self.dateProvider = dateProvider
    }

    func loadChallenges() -> [DailyChallenge] {
        challenges
    }

    func challengeForDate(_ date: Date) -> DailyChallenge {
        // Year rotation rule: the offset is measured from the global epoch, not
        // from this user's start date. The rotation still varies year over year,
        // but it varies for everyone at once, so a given civil date resolves to
        // the same challenge for every user regardless of when they enrolled.
        let offset = ChallengeScheduler.globalYearOffset(for: date)
        return scheduler.challengeForDate(date, yearOffset: offset)
    }

    func completeChallenge(_ challenge: DailyChallenge, on scheduledDate: Date, journal: String?) throws -> [BadgeDefinition] {
        let today = dateProvider()

        // Enrollment is checked before grace: a day from before the user joined
        // is ineligible no matter how recent it is, so the grace window can never
        // be used to backfill history that predates the account.
        guard scheduledDate.startOfDay >= enrollmentDate.startOfDay else {
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
