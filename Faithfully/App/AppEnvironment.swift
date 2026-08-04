import Foundation
import SwiftData
import Observation

/// Composition root: builds the single service graph shared by every tab for the
/// life of the app session — loaded challenges, services, the user profile, and
/// the per-tab view models. Challenge loading fails closed: if the bundle is
/// missing or malformed the app shows a blocking error with retry instead of
/// running on an empty pool.
@Observable
final class AppEnvironment {
    enum LoadState {
        case loading
        case ready(AppServices)
        case failed(String)
    }

    private(set) var state: LoadState = .loading

    /// Non-nil when the on-disk store could not be opened and the app is running
    /// on an in-memory stand-in. Surfaced by ContentView; nothing the user does
    /// in this state will persist, and they are told so.
    private(set) var storeFailure: PersistenceError?

    var services: AppServices? {
        if case .ready(let services) = state { return services }
        return nil
    }

    private let persistence: PersistenceCoordinating
    private let loadChallenges: () throws -> [DailyChallenge]
    private let notificationService: NotificationServiceProtocol
    private let dateProvider: () -> Date

    convenience init(
        modelContext: ModelContext,
        loadChallenges: @escaping () throws -> [DailyChallenge] = { try ChallengeLoader.loadChallenges() },
        notificationService: NotificationServiceProtocol = NotificationService(),
        dateProvider: @escaping () -> Date = { .now },
        storeFailure: PersistenceError? = nil
    ) {
        self.init(
            persistence: PersistenceCoordinator(context: modelContext),
            loadChallenges: loadChallenges,
            notificationService: notificationService,
            dateProvider: dateProvider,
            storeFailure: storeFailure
        )
    }

    init(
        persistence: PersistenceCoordinating,
        loadChallenges: @escaping () throws -> [DailyChallenge] = { try ChallengeLoader.loadChallenges() },
        notificationService: NotificationServiceProtocol = NotificationService(),
        dateProvider: @escaping () -> Date = { .now },
        storeFailure: PersistenceError? = nil
    ) {
        self.persistence = persistence
        self.loadChallenges = loadChallenges
        self.notificationService = notificationService
        self.dateProvider = dateProvider
        self.storeFailure = storeFailure
        load()
    }

    func retry() {
        load()
    }

    private func load() {
        state = .loading
        do {
            let challenges = try loadChallenges()
            let profile = try bootstrapProfile()
            let badgeService = BadgeService(persistence: persistence)
            let challengeService = try ChallengeService(
                persistence: persistence,
                challenges: challenges,
                badgeService: badgeService,
                enrollmentDate: profile.startDate,
                dateProvider: dateProvider
            )

            // Reconciliation on launch. Awarding is idempotent — it skips badges
            // already earned — so this is a cheap standing guarantee that the
            // badge set matches the completions actually on disk, whatever
            // happened during a previous run.
            //
            // Backfill any completion that reached V2 without passing through the
            // migration stage — a store created before the plan existed arrives
            // at V2 directly, and a row left at dayKey 0 would disappear from
            // every query. Idempotent and a no-op once done.
            _ = try? FaithfullyMigrationPlan.backfillDayKeys(in: persistence.context)

            // Collapse any day that somehow holds two completions, keeping
            // every reflection written against it. Unreachable through the app
            // since the completion guard started failing closed, so this is a
            // repair for a store from an earlier build — idempotent, and a
            // no-op on a healthy one.
            _ = try? CompletionReconciler.mergeDuplicateDays(in: persistence)

            // Best-effort on purpose, and the only remaining `try?` on a write:
            // this is a repair the user never asked for, so a failure must leave
            // the badge set exactly as it was and let the next launch retry,
            // not block the app from starting.
            try? persistence.transaction { _ = badgeService.evaluateAndStageAwards() }

            let services = AppServices(
                challenges: challenges,
                profile: profile,
                challengeService: challengeService,
                badgeService: badgeService,
                notificationService: notificationService,
                persistence: persistence,
                dateProvider: dateProvider
            )
            challengeService.onCompletionRecorded = { [weak services] scheduledDate, newBadges in
                services?.handleCompletionRecorded(on: scheduledDate, newBadges: newBadges)
            }
            state = .ready(services)
        } catch {
            state = .failed(errorMessage(for: error))
        }
    }

    /// Fetches the existing profile or creates it exactly once per install.
    /// Every consumer (tabs, settings, onboarding) sees this same profile.
    ///
    /// A failed fetch now propagates instead of collapsing to "no profile
    /// found". Swallowing it meant a transient read error created a *second*
    /// profile — a new enrollment date, reset preferences, and two owners of
    /// state that is supposed to be unique.
    private func bootstrapProfile() throws -> UserProfile {
        if let existing = try persistence.fetch(FetchDescriptor<UserProfile>()).first {
            return existing
        }
        // Enroll on the app's notion of today, not the wall clock: the injected
        // date provider is the single source of "now" for the whole graph, and
        // an enrollment date drawn from elsewhere would put the boundary out of
        // step with the calendar the user is actually looking at.
        let profile = UserProfile(startDate: dateProvider())
        try persistence.transaction { persistence.insert(profile) }
        return profile
    }

    private func errorMessage(for error: Error) -> String {
        switch error {
        case let persistenceError as PersistenceError:
            return persistenceError.message
        case ChallengeLoader.LoadError.fileNotFound:
            return "The challenge content could not be found. Please try again, or reinstall the app if the problem persists."
        case ChallengeLoader.LoadError.decodingFailed:
            return "The challenge content could not be read. Please try again, or reinstall the app if the problem persists."
        case ChallengeServiceError.emptyChallengePool:
            return "No challenges are available. Please try again, or reinstall the app if the problem persists."
        default:
            return "Something went wrong while loading your challenges. Please try again."
        }
    }
}

/// The app-session service graph plus the per-tab view models, all observing the
/// same completion truth.
final class AppServices {
    let challenges: [DailyChallenge]
    let profile: UserProfile
    let challengeService: ChallengeServiceProtocol
    let badgeService: BadgeServiceProtocol
    let notificationService: NotificationServiceProtocol
    private let dateProvider: () -> Date

    let dailyWalkViewModel: DailyWalkViewModel
    let calendarViewModel: CalendarViewModel
    let journeyViewModel: JourneyViewModel
    let settingsViewModel: SettingsViewModel

    init(
        challenges: [DailyChallenge],
        profile: UserProfile,
        challengeService: ChallengeServiceProtocol,
        badgeService: BadgeServiceProtocol,
        notificationService: NotificationServiceProtocol,
        persistence: PersistenceCoordinating,
        dateProvider: @escaping () -> Date
    ) {
        self.challenges = challenges
        self.profile = profile
        self.challengeService = challengeService
        self.badgeService = badgeService
        self.notificationService = notificationService
        self.dateProvider = dateProvider

        let today = dateProvider()
        self.dailyWalkViewModel = DailyWalkViewModel(
            challengeService: challengeService,
            today: today,
            translation: profile.preferredTranslation
        )
        self.calendarViewModel = CalendarViewModel(challengeService: challengeService, today: today)
        self.journeyViewModel = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        self.settingsViewModel = SettingsViewModel(persistence: persistence, profile: profile)

        // Settings is the single writer of preferences; every save flows back
        // through here so the other tabs and the pending notifications always
        // reflect the profile as it is now.
        settingsViewModel.onPreferencesChanged = { [weak self] in
            guard let self else { return }
            self.dailyWalkViewModel.updateTranslation(self.profile.preferredTranslation)
            self.refreshNotifications()
        }

        // A reflection edited or deleted in one tab must not linger, stale, in
        // the other — the Calendar day detail is a value type snapshot, and a
        // deleted reflection left showing there could be written back by
        // pressing Save on text the user already asked to destroy. Each side
        // only refreshes the *other*: `updateJournal` already refreshes its own
        // view model before firing this, so looping back would be redundant,
        // and each refresh method here never itself calls `updateJournal`, so
        // there is no recursion.
        journeyViewModel.onJournalChanged = { [weak self] in
            self?.calendarViewModel.refreshJournal()
        }
        calendarViewModel.onJournalChanged = { [weak self] in
            self?.journeyViewModel.refresh()
        }
    }

    /// Keeps every tab consistent after a completion (from Daily Walk or a
    /// Calendar grace recovery) without requiring a relaunch.
    func refreshAfterCompletion() {
        dailyWalkViewModel.refresh()
        calendarViewModel.loadMonth()
        journeyViewModel.refresh()
    }

    /// Runs after a completion is persisted: refreshes the tabs, re-runs the
    /// notification policy, and fires a celebration for any newly earned
    /// badges. The full policy pass — not just a same-day cancel — is what
    /// makes a grace recovery that lifts the streak past 7 arm the streak
    /// warning immediately; completing today still cancels tonight's evening
    /// reminder and streak warning via the policy's completed-today branch.
    /// Badge celebrations are enqueued after the policy pass so they can never
    /// race the daily rebuild (whose selective remove spares badge_* anyway).
    func handleCompletionRecorded(on scheduledDate: Date, newBadges: [BadgeDefinition]) {
        refreshAfterCompletion()
        refreshNotifications()

        guard !newBadges.isEmpty else { return }
        let earned = badgeService.earnedBadges()
        for definition in newBadges {
            if let badge = earned.first(where: { $0.badgeName == definition.id }) {
                notificationService.scheduleBadgeCelebration(
                    named: badge.badgeName,
                    preferences: NotificationPreferences(profile)
                )
            }
        }
    }

    /// Rebuilds the pending notification set from the profile as it is now:
    /// morning/evening per their flags and times, plus the streak warning when
    /// it applies (enabled, streak ≥ 7, today not yet completed). When today is
    /// already done, the evening reminder and streak warning are cancelled.
    /// Identifiers are stable, so re-running this replaces rather than stacks —
    /// safe to call on every foreground and settings change.
    func refreshNotifications() {
        // One snapshot per pass: read the model here, on the actor that owns it.
        let preferences = NotificationPreferences(profile)
        notificationService.scheduleAllNotifications(preferences: preferences)
        if challengeService.isCompleted(on: dateProvider()) {
            notificationService.cancelTodayReminders()
        } else {
            notificationService.scheduleStreakWarning(
                streak: challengeService.calculateStreak(),
                preferences: preferences,
                // The graph's clock, not the wall clock (#90). Everything else
                // here reads `dateProvider()`; this one call reached the
                // convenience overload defaulting to `.now`, so the warning
                // decided for itself what time it was. Identical in the shipped
                // app, where the provider *is* `.now` — but it made the suite's
                // result depend on the hour it ran at, because the warning is
                // only armed while its hour is still ahead.
                now: dateProvider()
            )
        }
    }

    /// Onboarding's finish path: ask for permission, then schedule. Scheduling
    /// even after a denial is intentional — the requests are inert until the
    /// user grants notifications in iOS Settings, at which point they fire
    /// without the app needing another pass.
    ///
    /// `@MainActor` because it reaches the view models and the profile, which
    /// only the UI ever touches. Left nonisolated, awaiting it from a SwiftUI
    /// view sends the whole non-Sendable service graph off the main actor.
    @MainActor
    func requestNotificationPermissionAndSchedule() async {
        _ = await notificationService.requestPermission()
        refreshNotifications()
    }

    /// Foreground refresh: re-reads the live date so a day rollover while the
    /// app stayed in memory moves Daily Walk and Calendar to the new day
    /// (challenge, completed state, today/future boundary, grace windows) —
    /// not just re-reads completion state for the launch day.
    func refreshForCurrentDate() {
        let today = dateProvider()
        dailyWalkViewModel.refresh(for: today)
        calendarViewModel.refresh(for: today)
        journeyViewModel.refresh()
        // Daily scheduling path: re-arms the evening reminder for the new day
        // (it is cancelled outright when a day is completed) and re-evaluates
        // the streak warning against the current streak and completion state.
        refreshNotifications()
    }
}
