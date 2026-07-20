import SwiftUI
import SwiftData

struct DailyWalkView: View {
    let vm: DailyWalkViewModel
    @State private var journalText = ""
    @State private var showJournalSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
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
                    DisclosureGroup {
                        Text(vm.yesterdayChallenge.challengeDescription)
                            .font(.body)
                    } label: {
                        Text("Yesterday: \(vm.yesterdayChallenge.title)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityIdentifier("yesterdayChallenge")
                }
                .padding()
            }
            .navigationTitle("Daily Walk")
            .sheet(isPresented: $showJournalSheet) {
                CompletionSheetView(
                    journalText: $journalText,
                    onComplete: {
                        vm.complete(journal: journalText.isEmpty ? nil : journalText)
                        showJournalSheet = false
                        journalText = ""
                    }
                )
            }
            .overlay {
                if vm.showCelebration {
                    BadgeCelebrationView(badges: vm.newBadges) {
                        vm.showCelebration = false
                    }
                    .accessibilityIdentifier("celebration")
                }
            }
        }
    }
}
