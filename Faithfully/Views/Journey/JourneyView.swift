import SwiftUI
import SwiftData

struct JourneyView: View {
    let vm: JourneyViewModel
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                        // Stats
                        HStack(spacing: 24) {
                            StatView(title: "Completed", value: "\(vm.totalCompleted)")
                            StatView(title: "Streak", value: "\(vm.currentStreak)")
                        }
                        .accessibilityIdentifier("statsSection")

                        // Journey progress
                        if let badge = vm.journeyBadge {
                            VStack(spacing: 8) {
                                BadgeGlyphView(
                                    type: .journey,
                                    category: nil,
                                    isEarned: badge.isEarned,
                                    size: 64
                                )
                                Text(badge.definition.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                ProgressView(value: badge.progress)
                                    .tint(.brandGold)
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
                                    BadgeGlyphView(
                                        type: badge.type,
                                        category: badge.category,
                                        isEarned: badge.isEarned
                                    )
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
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(entry.challengeTitle)
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        Spacer()
                                        ShareLink(item: vm.shareEntry(entry).shareText) {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.subheadline)
                                        }
                                        .accessibilityIdentifier("shareJournalEntry_\(entry.id)")
                                    }
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
                }
                .padding()
            }
            .navigationTitle("My Journey")
        }
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
