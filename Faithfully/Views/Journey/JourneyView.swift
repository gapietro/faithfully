import SwiftUI
import SwiftData

struct JourneyView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var vm: JourneyViewModel?
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let vm {
                        // Stats
                        HStack(spacing: 24) {
                            StatView(title: "Completed", value: "\(vm.totalCompleted)")
                            StatView(title: "Streak", value: "\(vm.currentStreak)")
                        }
                        .accessibilityIdentifier("statsSection")

                        // Journey progress
                        if let badge = vm.journeyBadge {
                            VStack(spacing: 8) {
                                Text(badge.definition.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                ProgressView(value: badge.progress)
                                    .accessibilityIdentifier("journeyProgress")
                                Text("\(badge.current) / \(badge.definition.threshold)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Badge grid
                        Text("Badges")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 16) {
                            ForEach(vm.allBadges) { badge in
                                VStack(spacing: 4) {
                                    Image(systemName: badge.isEarned ? "medal.fill" : "medal")
                                        .font(.title)
                                        .foregroundStyle(badge.isEarned ? .yellow : .gray)
                                    Text(badge.name)
                                        .font(.caption2)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                    if !badge.isEarned {
                                        ProgressView(value: badge.progress)
                                            .accessibilityIdentifier("badgeProgress_\(badge.id)")
                                    }
                                }
                                .accessibilityIdentifier("badge_\(badge.id)")
                            }
                        }
                        .accessibilityIdentifier("badgeGrid")

                        // Journal timeline
                        if !vm.journalEntries.isEmpty {
                            Text("Journal")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            TextField("Search journal...", text: $searchText)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityIdentifier("journalSearch")
                                .onChange(of: searchText) { _, newValue in
                                    vm.searchJournal(newValue)
                                }

                            ForEach(vm.journalEntries) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.challengeTitle)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(entry.journalText)
                                        .font(.body)
                                    Text(entry.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityIdentifier("journalEntry_\(entry.id)")
                            }
                        }
                    } else {
                        ProgressView()
                    }
                }
                .padding()
            }
            .navigationTitle("My Journey")
            .onAppear { setupViewModel() }
        }
    }

    private func setupViewModel() {
        guard vm == nil else { return }
        let challenges = (try? ChallengeLoader.loadChallenges()) ?? []
        let badgeService = BadgeService(modelContext: modelContext)
        let challengeService = ChallengeService(
            modelContext: modelContext, challenges: challenges, badgeService: badgeService
        )
        vm = JourneyViewModel(challengeService: challengeService, badgeService: badgeService)
    }
}

struct StatView: View {
    let title: String
    let value: String

    var body: some View {
        VStack {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
