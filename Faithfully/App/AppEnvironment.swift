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

    var services: AppServices? {
        if case .ready(let services) = state { return services }
        return nil
    }

    private let modelContext: ModelContext
    private let loadChallenges: () throws -> [DailyChallenge]
    private let notificationService: NotificationServiceProtocol
    private let dateProvider: () -> Date

    init(
        modelContext: ModelContext,
        loadChallenges: @escaping () throws -> [DailyChallenge] = { try ChallengeLoader.loadChallenges() },
        notificationService: NotificationServiceProtocol = NotificationService(),
        dateProvider: @escaping () -> Date = { .now }
    ) {
        self.modelContext = modelContext
        self.loadChallenges = loadChallenges
        self.notificationService = notificationService
        self.dateProvider = dateProvider
        load()
    }

    func retry() {
        load()
    }

    private func load() {
        state = .loading
        do {
            let challenges = try loadChallenges()
            let profile = bootstrapProfile()
            let badgeService = BadgeService(modelContext: modelContext)
            let challengeService = try ChallengeService(
                modelContext: modelContext,
                challenges: challenges,
                badgeService: badgeService,
                userStartDate: profile.startDate,
                dateProvider: dateProvider
            )
            let services = AppServices(
                challenges: challenges,
                profile: profile,
                challengeService: challengeService,
                badgeService: badgeService,
                notificationService: notificationService,
                modelContext: modelContext,
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
    private func bootstrapProfile() -> UserProfile {
        let descriptor = FetchDescriptor<UserProfile>()
        if let existing = ((try? modelContext.fetch(descriptor)) ?? []).first {
            return existing
        }
        let profile = UserProfile()
        modelContext.insert(profile)
        try? modelContext.save()
        return profile
    }

    private func errorMessage(for error: Error) -> String {
        switch error {
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
        modelContext: ModelContext,
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
        self.settingsViewModel = SettingsViewModel(modelContext: modelContext)

        // Settings is the single writer of preferences; every save flows back
        // through here so the other tabs and the pending notifications always
        // reflect the profile as it is now.
        settingsViewModel.onPreferencesChanged = { [weak self] in
            guard let self else { return }
            self.dailyWalkViewModel.updateTranslation(self.profile.preferredTranslation)
            self.refreshNotifications()
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
                notificationService.scheduleBadgeCelebration(badge, profile: profile)
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
        notificationService.scheduleAllNotifications(profile: profile)
        if challengeService.isCompleted(on: dateProvider()) {
            notificationService.cancelTodayReminders()
        } else {
            notificationService.scheduleStreakWarning(
                streak: challengeService.calculateStreak(),
                profile: profile
            )
        }
    }

    /// Onboarding's finish path: ask for permission, then schedule. Scheduling
    /// even after a denial is intentional — the requests are inert until the
    /// user grants notifications in iOS Settings, at which point they fire
    /// without the app needing another pass.
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
