import SwiftUI
import SwiftData

struct DailyWalkView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: DailyWalkViewModel?
    @State private var journalText = ""
    @State private var showJournalSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let vm {
                        // Streak counter
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(vm.currentStreak) day streak")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .accessibilityIdentifier("streakCounter")

                        // Challenge card
                        ChallengeCardView(challenge: vm.todayChallenge, translation: vm.translation)

                        // Completion button
                        if vm.isCompleted {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                                .accessibilityIdentifier("completedLabel")
                        } else {
                            Button(action: {
                                showJournalSheet = true
                            }) {
                                Text("I Did It")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.accentColor)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .accessibilityIdentifier("iDidItButton")
                        }

                        // Yesterday's challenge (collapsed)
                        if let yesterday = yesterdayChallenge(vm: vm) {
                            DisclosureGroup {
                                Text(yesterday.challengeDescription)
                                    .font(.body)
                            } label: {
                                Text("Yesterday: \(yesterday.title)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .accessibilityIdentifier("yesterdayChallenge")
                        }
                    } else {
                        ProgressView()
                    }
                }
                .padding()
            }
            .navigationTitle("Daily Walk")
            .onAppear { setupViewModel() }
            .sheet(isPresented: $showJournalSheet) {
                CompletionSheetView(
                    journalText: $journalText,
                    onComplete: {
                        vm?.complete(journal: journalText.isEmpty ? nil : journalText)
                        showJournalSheet = false
                        journalText = ""
                    }
                )
            }
            .overlay {
                if vm?.showCelebration == true {
                    BadgeCelebrationView(badges: vm?.newBadges ?? []) {
                        vm?.showCelebration = false
                    }
                    .accessibilityIdentifier("celebration")
                }
            }
        }
    }

    private func setupViewModel() {
        guard vm == nil else { return }
        let challenges = (try? ChallengeLoader.loadChallenges()) ?? []
        let badgeService = BadgeService(modelContext: modelContext)
        let challengeService = ChallengeService(
            modelContext: modelContext, challenges: challenges, badgeService: badgeService
        )
        vm = DailyWalkViewModel(challengeService: challengeService)
    }

    private func yesterdayChallenge(vm: DailyWalkViewModel) -> DailyChallenge? {
        let challenges = (try? ChallengeLoader.loadChallenges()) ?? []
        let scheduler = ChallengeScheduler(challenges: challenges)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        return scheduler.challengeForDate(yesterday)
    }
}
