import Foundation
import SwiftData

enum ChallengeServiceError: Error {
    case gracePeriodExpired
    case alreadyCompleted
    case emptyChallengePool
}

protocol ChallengeServiceProtocol {
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
    private let userStartDate: Date
    private let dateProvider: () -> Date

    /// Called after a completion is persisted. The composition root uses this to
    /// refresh the other tabs' view models so they share the same completion truth.
    var onCompletionRecorded: (() -> Void)?

    init(
        modelContext: ModelContext,
        challenges: [DailyChallenge],
        badgeService: BadgeServiceProtocol,
        userStartDate: Date = .now,
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
        self.userStartDate = userStartDate
        self.dateProvider = dateProvider
    }

    func loadChallenges() -> [DailyChallenge] {
        challenges
    }

    func challengeForDate(_ date: Date) -> DailyChallenge {
        // Year rotation rule: the offset is the number of whole years between the
        // user's start date and the target date (PRD §11.4, SPARC getYearOffset),
        // so a returning user's Year 2 pairs dates with different challenges than Year 1.
        let offset = ChallengeScheduler.yearOffset(from: userStartDate, to: date)
        return scheduler.challengeForDate(date, yearOffset: offset)
    }

    func completeChallenge(_ challenge: DailyChallenge, on scheduledDate: Date, journal: String?) throws -> [BadgeDefinition] {
        let today = dateProvider()

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
        onCompletionRecorded?()
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
