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
    private let dateProvider: () -> Date

    init(
        modelContext: ModelContext,
        loadChallenges: @escaping () throws -> [DailyChallenge] = { try ChallengeLoader.loadChallenges() },
        dateProvider: @escaping () -> Date = { .now }
    ) {
        self.modelContext = modelContext
        self.loadChallenges = loadChallenges
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
                notificationService: NotificationService(),
                modelContext: modelContext,
                dateProvider: dateProvider
            )
            challengeService.onCompletionRecorded = { [weak services] in
                services?.refreshAfterCompletion()
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
        dateProvider: () -> Date
    ) {
        self.challenges = challenges
        self.profile = profile
        self.challengeService = challengeService
        self.badgeService = badgeService
        self.notificationService = notificationService

        let today = dateProvider()
        self.dailyWalkViewModel = DailyWalkViewModel(challengeService: challengeService, today: today)
        self.calendarViewModel = CalendarViewModel(challengeService: challengeService, today: today)
        self.journeyViewModel = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
        self.settingsViewModel = SettingsViewModel(modelContext: modelContext)
    }

    /// Keeps every tab consistent after a completion (from Daily Walk or a
    /// Calendar grace recovery) without requiring a relaunch.
    func refreshAfterCompletion() {
        dailyWalkViewModel.refresh()
        calendarViewModel.loadMonth()
        journeyViewModel.refresh()
    }
}
