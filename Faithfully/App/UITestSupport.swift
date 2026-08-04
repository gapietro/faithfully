#if DEBUG
import Foundation
import SwiftData

/// Deterministic launch state for UI tests.
///
/// Before this existed, UI tests ran against whatever the simulator happened to
/// contain, so they could only assert that elements were *present* — a test
/// named "completed days show a coloured indicator" could not seed a completed
/// day, so it asserted that a day existed and passed forever.
///
/// Compiled only in DEBUG, and only acts when the launch argument is present.
/// The App Store build does not contain this code at all, so no combination of
/// runtime input can reach it.
///
/// ## Protocol
///
/// ```
/// app.launchArguments = ["-FaithfullyUITestScenario", "<scenario>"]
/// ```
///
/// Every scenario wipes the store first, so tests never inherit each other's
/// state. Scenarios are anchored to the real current date, because that is what
/// the app itself uses to decide today, grace windows, and the calendar month.
enum UITestSupport {
    static let scenarioArgument = "-FaithfullyUITestScenario"

    /// Forces the app to launch on the in-memory stand-in, as if the on-disk
    /// store could not be opened, so the store-unavailable banner and its reset
    /// confirmation are reachable. Independent of `scenarioArgument`: a
    /// scenario still seeds, it just seeds the in-memory container.
    static let forceStoreFailureArgument = "-FaithfullyUITestForceStoreFailure"

    static var forcesStoreFailure: Bool {
        ProcessInfo.processInfo.arguments.contains(forceStoreFailureArgument)
    }

    enum Scenario: String {
        /// Empty store, enrolled today. Every earlier day is pre-enrollment.
        case fresh
        /// Enrolled 90 days ago with 40 consecutive completions ending
        /// yesterday, journal text on some of them, and the 5K badge earned.
        /// Today is deliberately left open so the completion flow is testable.
        case seeded
        /// As `seeded`, plus today already completed.
        case completedToday
        /// Enrolled 90 days ago, completions ending three days ago, so
        /// yesterday sits inside the grace window and is recoverable.
        case graceAvailable
    }

    static var requestedScenario: Scenario? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: scenarioArgument),
              index + 1 < arguments.count else { return nil }
        return Scenario(rawValue: arguments[index + 1])
    }

    /// Pins the app's notion of "now" to an ISO 8601 instant.
    ///
    /// ```
    /// app.launchArguments += ["-FaithfullyUITestFixedDate", "2026-03-15T12:00:00Z"]
    /// ```
    ///
    /// The daily challenge rotates, so its text length — and therefore the
    /// vertical position of every control below it — changes from one day to the
    /// next. A test that measures *where* something is rendered is otherwise
    /// asserting against the calendar, and the same commit renders differently
    /// tomorrow. That is what made the accessibility gate non-deterministic
    /// (#89): it passed locally and failed on a runner that had already crossed
    /// midnight UTC.
    ///
    /// Feeds both the seeded store and the live service graph, so scenario
    /// offsets and the app's own "today" cannot disagree.
    static let fixedDateArgument = "-FaithfullyUITestFixedDate"

    static var fixedDate: Date? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: fixedDateArgument),
              index + 1 < arguments.count else { return nil }
        return ISO8601DateFormatter().date(from: arguments[index + 1])
    }

    /// The date the app should run against: the pinned instant when a test asked
    /// for one, the wall clock otherwise.
    static var today: Date { fixedDate ?? .now }

    /// A date provider for the service graph, so `AppEnvironment` reads the same
    /// "now" the store was seeded against.
    static var dateProvider: (() -> Date)? {
        guard let fixedDate else { return nil }
        return { fixedDate }
    }

    /// Journal text the tests search for. Distinctive enough that a substring
    /// match cannot succeed by accident.
    static let searchableJournalText = "seeded-journal-marker-alpha"
    static let otherJournalText = "seeded-journal-marker-beta"

    static func apply(_ scenario: Scenario, in context: ModelContext, today: Date = .now) {
        wipe(context)

        let challenges = (try? ChallengeLoader.loadChallenges()) ?? []
        guard let scheduler = ChallengeScheduler(challenges: challenges) else { return }
        func challenge(for date: Date) -> DailyChallenge {
            scheduler.challengeForDate(date, yearOffset: ChallengeScheduler.globalYearOffset(for: date))
        }

        let enrollment: Date
        let completedOffsets: [Int]

        switch scenario {
        case .fresh:
            enrollment = today
            completedOffsets = []
        case .seeded:
            enrollment = today.addingDays(-90)
            completedOffsets = Array(1...40)
        case .completedToday:
            enrollment = today.addingDays(-90)
            completedOffsets = Array(0...40)
        case .graceAvailable:
            enrollment = today.addingDays(-90)
            // Ends three days ago: yesterday and the day before are open and
            // still inside the three-day grace window.
            completedOffsets = Array(3...40)
        }

        context.insert(UserProfile(startDate: enrollment))

        for (index, offset) in completedOffsets.enumerated() {
            let date = today.addingDays(-offset)
            let daily = challenge(for: date)
            let journal: String?
            switch index {
            case 0: journal = searchableJournalText
            case 1: journal = otherJournalText
            default: journal = index % 5 == 0 ? "routine reflection \(index)" : nil
            }
            context.insert(CompletedChallenge(
                challengeId: daily.id,
                challengeCategory: daily.category.rawValue,
                completedDate: date,
                scheduledDate: date.startOfDay,
                dayKey: CivilDay.key(for: date),
                journalEntry: journal
            ))
        }

        try? context.save()

        // Award through the real evaluator rather than inserting badge rows by
        // hand, so a seeded store is one the app could actually have produced.
        let badgeService = BadgeService(persistence: PersistenceCoordinator(context: context))
        try? PersistenceCoordinator(context: context).transaction {
            _ = badgeService.evaluateAndStageAwards()
        }
    }

    private static func wipe(_ context: ModelContext) {
        try? context.delete(model: CompletedChallenge.self)
        try? context.delete(model: EarnedBadge.self)
        try? context.delete(model: UserProfile.self)
        try? context.save()
    }
}
#endif
