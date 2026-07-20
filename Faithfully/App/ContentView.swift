import SwiftUI
import SwiftData

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
            if hasCompletedOnboarding {
                MainTabView(services: services)
            } else {
                OnboardingView(onComplete: {
                    hasCompletedOnboarding = true
                })
            }
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
        .onChange(of: scenePhase) { _, newPhase in
            // Re-read completion state on foreground so grace-period expiry or
            // changes made while backgrounded are reflected without a relaunch.
            if newPhase == .active {
                services.refreshAfterCompletion()
            }
        }
    }
}
