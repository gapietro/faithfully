import Foundation
import SwiftData

enum ChallengeServiceError: Error {
    case gracePeriodExpired
    case alreadyCompleted
}

protocol ChallengeServiceProtocol {
    func loadChallenges() -> [DailyChallenge]
    func challengeForDate(_ date: Date) -> DailyChallenge
    func completeChallenge(_ challenge: DailyChallenge, on scheduledDate: Date, journal: String?) throws -> [BadgeDefinition]
    func isCompleted(challengeId: String) -> Bool
    func fetchCompletions(for dateRange: ClosedRange<Date>) -> [CompletedChallenge]
    func calculateStreak() -> Int
}

final class ChallengeService: ChallengeServiceProtocol {
    private let modelContext: ModelContext
    private let challenges: [DailyChallenge]
    private let scheduler: ChallengeScheduler
    private let badgeService: BadgeServiceProtocol
    private let dateProvider: () -> Date

    init(
        modelContext: ModelContext,
        challenges: [DailyChallenge],
        badgeService: BadgeServiceProtocol,
        dateProvider: @escaping () -> Date = { .now }
    ) {
        self.modelContext = modelContext
        self.challenges = challenges
        self.scheduler = ChallengeScheduler(challenges: challenges)
        self.badgeService = badgeService
        self.dateProvider = dateProvider
    }

    func loadChallenges() -> [DailyChallenge] {
        challenges
    }

    func challengeForDate(_ date: Date) -> DailyChallenge {
        scheduler.challengeForDate(date)
    }

    func completeChallenge(_ challenge: DailyChallenge, on scheduledDate: Date, journal: String?) throws -> [BadgeDefinition] {
        let today = dateProvider()

        guard GracePeriod.canComplete(challengeDate: scheduledDate, today: today) else {
            throw ChallengeServiceError.gracePeriodExpired
        }

        guard !isCompleted(challengeId: challenge.id) else {
            throw ChallengeServiceError.alreadyCompleted
        }

        let trimmedJournal = journal?.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalJournal = trimmedJournal.flatMap { $0.isEmpty ? nil : String($0.prefix(Constants.maxJournalLength)) }

        let completion = CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: today,
            scheduledDate: scheduledDate,
            journalEntry: finalJournal
        )

        modelContext.insert(completion)
        try modelContext.save()

        let newBadges = badgeService.evaluateAndAward()
        return newBadges
    }

    func isCompleted(challengeId: String) -> Bool {
        let descriptor = FetchDescriptor<CompletedChallenge>(
            predicate: #Predicate { $0.challengeId == challengeId }
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
