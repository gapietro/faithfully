import SwiftUI
import SwiftData

extension DarkModePreference {
    /// SwiftUI override for this preference; `.system` means no override.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

struct ContentView: View {
    /// Rebuilds the store after the user explicitly asks to reset an unreadable
    /// one. A non-optional parameter on purpose: this used to be a mutable
    /// callback on `AppEnvironment`, attached once from `.onAppear`. Resetting
    /// replaces the environment, `.onAppear` never fires again for the same
    /// view identity, and the recovery button went dead on the second attempt —
    /// exactly when someone whose store is still unreadable needs it. Passed in
    /// rather than stored, it cannot go missing.
    let onResetStore: () -> Void

    @Environment(AppEnvironment.self) private var appEnvironment
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        switch appEnvironment.state {
        case .loading:
            ProgressView()
        case .failed(let message):
            ChallengeLoadErrorView(message: message) {
                appEnvironment.retry()
            }
        case .ready(let services):
            Group {
                if hasCompletedOnboarding {
                    VStack(spacing: 0) {
                        // Above the tabs, not inside one: a store failure affects
                        // every tab, and burying it in Settings would let a user
                        // write a journal entry that is silently going nowhere.
                        if let failure = appEnvironment.storeFailure {
                            StoreUnavailableBanner(message: failure.message, onReset: onResetStore)
                            .padding(.top, 8)
                        }
                        MainTabView(services: services)
                    }
                } else {
                    OnboardingView(
                        onComplete: {
                            hasCompletedOnboarding = true
                        },
                        requestNotificationPermission: {
                            await services.requestNotificationPermissionAndSchedule()
                        }
                    )
                }
            }
            // darkMode lives on the observable settings view model, so a change
            // in Settings re-renders the whole tree with the new scheme live.
            .preferredColorScheme(services.settingsViewModel.darkMode.colorScheme)
        }
    }
}

struct MainTabView: View {
    let services: AppServices
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            DailyWalkView(vm: services.dailyWalkViewModel)
                .tabItem {
                    Label("Daily Walk", systemImage: "figure.walk")
                }
            CalendarScreenView(vm: services.calendarViewModel)
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            JourneyView(vm: services.journeyViewModel)
                .tabItem {
                    Label("Journey", systemImage: "trophy")
                }
            SettingsView(vm: services.settingsViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .task {
            // Launch-time scheduling pass: scenePhase does not reliably deliver
            // a change for the initial activation, and the pending notification
            // set must match today's completion state from the first frame.
            services.refreshNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Re-read the current date and completion state on foreground so a
            // day rollover, grace-period expiry, or changes made while
            // backgrounded are reflected without a relaunch.
            if newPhase == .active {
                services.refreshForCurrentDate()
            }
        }
    }
}
