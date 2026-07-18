import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView(onComplete: {
                hasCompletedOnboarding = true
            })
        }
    }
}

struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            DailyWalkView()
                .tabItem {
                    Label("Daily Walk", systemImage: "figure.walk")
                }
            CalendarScreenView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            JourneyView()
                .tabItem {
                    Label("Journey", systemImage: "trophy")
                }
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
