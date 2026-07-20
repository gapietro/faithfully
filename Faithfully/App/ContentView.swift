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
                    MainTabView(services: services)
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
