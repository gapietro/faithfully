import SwiftUI
import SwiftData

struct JourneyView: View {
    let vm: JourneyViewModel
    @State private var searchText = ""
    @State private var editingEntry: JournalDisplayItem?
    @State private var pendingDeletion: JournalDisplayItem?
    /// Set when a delete fails, so the user is told rather than left to
    /// believe writing is gone when it is still on disk.
    @State private var deleteFailureMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                        // Stats
                        HStack(spacing: 24) {
                            StatView(
                                title: "Completed",
                                value: "\(vm.totalCompleted)",
                                valueIdentifier: "statTotalCompleted"
                            )
                            StatView(
                                title: "Streak",
                                value: "\(vm.currentStreak)",
                                valueIdentifier: "statCurrentStreak"
                            )
                        }

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
                                    // Decorative: a 4pt-tall bar can never meet
                                    // the 44pt hit-area rule, and the same value
                                    // is announced by the "n / threshold" text
                                    // immediately below it.
                                    .accessibilityHidden(true)
                                Text("\(badge.current) / \(badge.definition.threshold)")
                                    .font(.caption)
                                    .foregroundStyle(Color.supportingText)
                            }
                        }

                        // Badge grid
                        Text("Badges")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // 96pt rather than 80: at 80 the longest badge names
                        // ("Prayer Beginner", "Unquenchable") clipped, and the
                        // audit flagged them as unsupported at larger type sizes.
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96))], spacing: 16) {
                            ForEach(vm.allBadges) { badge in
                                VStack(spacing: 6) {
                                    BadgeGlyphView(
                                        type: badge.type,
                                        category: badge.category,
                                        isEarned: badge.isEarned
                                    )
                                    Text(badge.name)
                                        .font(.caption)
                                        .foregroundStyle(Color.primary)
                                        .lineLimit(3)
                                        .minimumScaleFactor(0.75)
                                        .multilineTextAlignment(.center)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if !badge.isEarned {
                                        ProgressView(value: badge.progress)
                                            .accessibilityIdentifier("badgeProgress_\(badge.id)")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 4)
                                // A definite background: without one the audit
                                // measures the name against whatever happens to
                                // be behind it, and so does a reader.
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .accessibilityElement(children: .combine)
                                .accessibilityIdentifier("badge_\(badge.id)")
                                .accessibilityLabel(badge.name)
                                // Earned-ness is otherwise only a colour, which
                                // neither VoiceOver nor a UI test can perceive.
                                .accessibilityValue(badge.isEarned
                                    ? "Earned"
                                    : "Not earned, \(badge.current) of \(badge.threshold)")
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
                                        .foregroundStyle(Color.supportingText)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .accessibilityIdentifier("journalEntry_\(entry.id)")
                                .contentShape(Rectangle())
                                .onTapGesture { editingEntry = entry }
                                .accessibilityHint("Double tap to edit this reflection")
                                .accessibilityAction(named: "Edit") { editingEntry = entry }
                                .accessibilityAction(named: "Delete") { pendingDeletion = entry }
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        pendingDeletion = entry
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.footnote)
                                            .foregroundStyle(Color.supportingText)
                                            // 44pt tappable area, not 13pt of ink.
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .accessibilityIdentifier("deleteJournalEntry_\(entry.id)")
                                    .accessibilityLabel("Delete reflection")
                                }
                            }
                        }
                }
                .padding()
                // Keeps the last row clear of the translucent tab bar.
                // Resting underneath it, text is measured — and read —
                // against the blur rather than the background.
                .padding(.bottom, 32)
            }
            .navigationTitle("My Journey")
            .sheet(item: $editingEntry) { entry in
                JournalEditSheet(
                    title: "Edit reflection",
                    date: entry.date,
                    originalText: entry.journalText,
                    onSave: { vm.updateJournal(entryID: entry.id, to: $0) },
                    onCancel: { editingEntry = nil }
                )
            }
            .reflectionDeleteAlert(
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { if !$0 { pendingDeletion = nil } }
                ),
                date: pendingDeletion?.date,
                onDelete: {
                    if let entry = pendingDeletion {
                        switch vm.updateJournal(entryID: entry.id, to: nil) {
                        case .saved:
                            break
                        case .failed(let failure):
                            // The alert already dismissed; tell the user the
                            // writing they just asked to delete is still there.
                            deleteFailureMessage = failure.message
                        }
                    }
                    pendingDeletion = nil
                },
                onCancel: { pendingDeletion = nil }
            )
            .alert(
                "Couldn't delete reflection",
                isPresented: Binding(
                    get: { deleteFailureMessage != nil },
                    set: { if !$0 { deleteFailureMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { deleteFailureMessage = nil }
            } message: {
                Text(deleteFailureMessage ?? "")
            }
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    /// Identifies the number itself. A container identifier is unreliable here —
    /// SwiftUI may or may not expose a combined stack as its own element — and
    /// the number is what both VoiceOver and the tests actually want.
    var valueIdentifier: String?

    var body: some View {
        VStack {
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .accessibilityIdentifier(valueIdentifier ?? "")
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.supportingText)
        }
    }
}
