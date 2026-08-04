import Foundation
import SwiftData

enum ChallengeServiceError: Error, Equatable {
    case gracePeriodExpired
    case alreadyCompleted
    case emptyChallengePool
    case beforeEnrollment
    /// The journal exceeded the limit. Reported rather than trimmed: silently
    /// discarding the tail of a private reflection is data loss the user never
    /// consented to and cannot detect.
    case journalTooLong(limit: Int, actual: Int)
}

protocol ChallengeServiceProtocol {
    /// The first day this user is eligible to complete. Earlier days are not
    /// missed days — they are not this user's days at all, and no completion,
    /// streak, or badge credit may be earned for them.
    var enrollmentDate: Date { get }

    func loadChallenges() -> [DailyChallenge]
    func challengeForDate(_ date: Date) -> DailyChallenge
    func completeChallenge(_ challenge: DailyChallenge, on scheduledDate: Date, journal: String?) throws -> [BadgeDefinition]

    /// Replaces the reflection on an existing completion. `nil` clears it.
    ///
    /// Only `journalEntry` changes: the day, the challenge and the completion
    /// timestamp are untouched, so streak, totals and badges cannot move.
    func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult

    func isCompleted(on scheduledDate: Date) -> Bool
    func fetchCompletions(for dateRange: ClosedRange<Date>) -> [CompletedChallenge]

    /// Every completion ever recorded, with no date bounds. Totals and journal
    /// search must not be clipped by a sentinel range — BadgeService already
    /// counts without bounds, so any bounded caller disagrees with it silently.
    func fetchAllCompletions() -> [CompletedChallenge]

    func calculateStreak() -> Int
}

final class ChallengeService: ChallengeServiceProtocol {
    private let persistence: PersistenceCoordinating
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

    convenience init(
        modelContext: ModelContext,
        challenges: [DailyChallenge],
        badgeService: BadgeServiceProtocol,
        enrollmentDate: Date = .now,
        dateProvider: @escaping () -> Date = { .now }
    ) throws {
        try self.init(
            persistence: PersistenceCoordinator(context: modelContext),
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: enrollmentDate,
            dateProvider: dateProvider
        )
    }

    init(
        persistence: PersistenceCoordinating,
        challenges: [DailyChallenge],
        badgeService: BadgeServiceProtocol,
        enrollmentDate: Date = .now,
        dateProvider: @escaping () -> Date = { .now }
    ) throws {
        // Fail closed: never build a scheduler over an empty non-giving pool.
        guard let scheduler = ChallengeScheduler(challenges: challenges) else {
            throw ChallengeServiceError.emptyChallengePool
        }
        self.persistence = persistence
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
        //
        // Read strictly, unlike `isCompleted`. Reads are lenient across this app
        // because a failed read should degrade a progress bar rather than block
        // someone — but this one is a *write guard*, and a fetch error collapsing
        // to "not completed yet" is how a day gets recorded twice. A duplicate
        // inflates totals, category counts and therefore badges, and nothing
        // would ever repair it.
        guard try completionCount(on: scheduledDate) == 0 else {
            throw ChallengeServiceError.alreadyCompleted
        }

        // One rule, shared with the edit path — see JournalText.
        let finalJournal: String?
        do {
            finalJournal = try JournalText.validated(journal)
        } catch JournalValidationError.tooLong(let limit, let actual) {
            throw ChallengeServiceError.journalTooLong(limit: limit, actual: actual)
        }

        let completion = CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: today,
            scheduledDate: scheduledDate.startOfDay,
            dayKey: CivilDay.key(for: scheduledDate),
            journalEntry: finalJournal
        )

        // One transaction: the completion and the badges it earns commit together
        // or not at all. Two separate saves meant a process death between them
        // left a completion whose badge was never awarded — invisible to the user
        // and only repaired by chance on some later completion.
        var newBadges: [BadgeDefinition] = []
        try persistence.transaction {
            persistence.insert(completion)
            newBadges = badgeService.evaluateAndStageAwards()
        }

        onCompletionRecorded?(scheduledDate, newBadges)
        return newBadges
    }

    func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult {
        let validated: String?
        do {
            validated = try JournalText.validated(text)
        } catch JournalValidationError.tooLong(let limit, let actual) {
            return .failed(.tooLong(limit: limit, actual: actual))
        } catch {
            return .failed(.couldNotSave)
        }

        let descriptor = FetchDescriptor<CompletedChallenge>(
            predicate: #Predicate { $0.id == entryID }
        )
        let existing: CompletedChallenge?
        do {
            existing = try persistence.fetch(descriptor).first
        } catch {
            return .failed(.couldNotRead)
        }
        guard let entry = existing else {
            return .failed(.entryNotFound)
        }

        // Captured before mutating: `transaction` rolls the context back on
        // failure, but restoring the in-memory object explicitly means the
        // caller never sees a half-applied edit either way.
        let previous = entry.journalEntry
        do {
            try persistence.transaction { entry.journalEntry = validated }
            return .saved
        } catch {
            entry.journalEntry = previous
            return .failed(.couldNotSave)
        }
    }

    /// Matches on the frozen civil day, not on an instant range. The old
    /// half-open `scheduledDate` window re-derived the day from the device's
    /// current time zone on every read, so the same row could fall inside the
    /// window before a trip and outside it after.
    func isCompleted(on scheduledDate: Date) -> Bool {
        // Lenient on purpose: this drives display and notification policy, where
        // a read failure should not stop the app working. The write path uses
        // `completionCount` and refuses when it cannot tell.
        ((try? completionCount(on: scheduledDate)) ?? 0) > 0
    }

    /// How many completions exist for a civil day. Throws rather than reporting
    /// zero when the store cannot be read.
    private func completionCount(on scheduledDate: Date) throws -> Int {
        let key = CivilDay.key(for: scheduledDate)
        let descriptor = FetchDescriptor<CompletedChallenge>(
            predicate: #Predicate { $0.dayKey == key }
        )
        return try persistence.fetch(descriptor).count
    }

    func fetchCompletions(for dateRange: ClosedRange<Date>) -> [CompletedChallenge] {
        let start = CivilDay.key(for: dateRange.lowerBound)
        let end = CivilDay.key(for: dateRange.upperBound)
        let descriptor = FetchDescriptor<CompletedChallenge>(
            predicate: #Predicate { $0.dayKey >= start && $0.dayKey <= end }
        )
        return (try? persistence.fetch(descriptor)) ?? []
    }

    func fetchAllCompletions() -> [CompletedChallenge] {
        (try? persistence.fetch(FetchDescriptor<CompletedChallenge>())) ?? []
    }

    func calculateStreak() -> Int {
        let descriptor = FetchDescriptor<CompletedChallenge>()
        let completions = (try? persistence.fetch(descriptor)) ?? []
        return StreakCalculator.calculateStreak(
            completedDayKeys: completions.map(\.dayKey),
            today: dateProvider()
        )
    }
}
