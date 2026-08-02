import SwiftUI
import SwiftData

struct DailyWalkView: View {
    let vm: DailyWalkViewModel
    @State private var journalText = ""
    @State private var showJournalSheet = false
    @State private var completionError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Streak counter
                    HStack {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(Color.brandGold)
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
                            .foregroundStyle(Color.brandForest)
                            .accessibilityIdentifier("completedLabel")
                    } else {
                        Button(action: {
                            completionError = nil
                            showJournalSheet = true
                        }) {
                            Text("I Did It")
                                .font(.headline)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brandNavy)
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
                            .accessibilityIdentifier("yesterdayChallengeTitle")
                    }
                    .accessibilityIdentifier("yesterdayChallenge")
                }
                .padding()
            }
            .navigationTitle("Daily Walk")
            .sheet(isPresented: $showJournalSheet) {
                CompletionSheetView(
                    journalText: $journalText,
                    errorMessage: completionError,
                    onComplete: {
                        // The draft is cleared and the sheet dismissed only on a
                        // confirmed success. On any failure both survive, so the
                        // user still has what they wrote.
                        switch vm.complete(journal: journalText.isEmpty ? nil : journalText) {
                        case .completed:
                            completionError = nil
                            showJournalSheet = false
                            journalText = ""
                        case .failed(let failure):
                            completionError = failure.message
                        }
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
