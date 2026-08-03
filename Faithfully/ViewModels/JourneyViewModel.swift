import Foundation
import SwiftData
import Observation

@Observable
final class JourneyViewModel {
    var totalCompleted: Int = 0
    var currentStreak: Int = 0
    var journeyBadge: BadgeProgress?
    var allBadges: [BadgeDisplayItem] = []
    var journalEntries: [JournalDisplayItem] = []

    /// The query currently filtering the timeline, so a refresh after an edit
    /// re-applies it instead of dropping the user back to the unfiltered list.
    private(set) var activeSearchQuery: String = ""

    private let challengeService: ChallengeServiceProtocol
    private let badgeService: BadgeServiceProtocol

    init(challengeService: ChallengeServiceProtocol, badgeService: BadgeServiceProtocol) {
        self.challengeService = challengeService
        self.badgeService = badgeService
        refresh()
    }

    func refresh() {
        currentStreak = challengeService.calculateStreak()

        // Load all completions
        let completions = allCompletions()
        totalCompleted = completions.count

        // Journey badge progress — find next unearned or highest earned
        let journeyDefs = BadgeDefinition.allJourneyBadges
        journeyBadge = journeyDefs
            .map { badgeService.progress(for: $0) }
            .first { !$0.isEarned } ?? journeyDefs.last.map { badgeService.progress(for: $0) }

        // All badges
        let allDefs = badgeService.allBadgeDefinitions()
        allBadges = allDefs.map { def in
            let progress = badgeService.progress(for: def)
            return BadgeDisplayItem(
                id: def.id,
                name: def.name,
                type: def.type,
                category: def.category,
                threshold: def.threshold,
                current: progress.current,
                isEarned: progress.isEarned,
                earnedDate: progress.earnedDate
            )
        }

        // Journal entries — reverse chronological, honouring any active filter.
        journalEntries = journalItems(
            from: completions,
            matching: activeSearchQuery.isEmpty ? nil : activeSearchQuery
        )
    }

    func searchJournal(_ query: String) {
        activeSearchQuery = query
        guard !query.isEmpty else {
            refresh()
            return
        }
        journalEntries = journalItems(from: allCompletions(), matching: query)
    }

    /// Edits or clears a reflection, then rebuilds the timeline.
    ///
    /// Returns the result rather than swallowing it: the caller owns the editor
    /// and the user's text, and must keep both unless this says `.saved`.
    @discardableResult
    func updateJournal(entryID: UUID, to text: String?) -> JournalEditResult {
        let result = challengeService.updateJournal(entryID: entryID, to: text)
        guard result.isSaved else { return result }
        refresh()
        return result
    }

    func shareEntry(_ entry: JournalDisplayItem) -> ShareCardData {
        ShareCardData(
            title: entry.challengeTitle,
            category: entry.category,
            date: entry.date,
            scriptureReference: entry.scriptureReference,
            journalText: entry.journalText,
            streakCount: currentStreak
        )
    }

    /// Unbounded on purpose. This used to be a 2020…2030 sentinel window, which
    /// meant a completion outside it vanished from totals, journal, and search
    /// while BadgeService's unbounded fetch still counted it — the same app
    /// reporting two different totals.
    private func allCompletions() -> [CompletedChallenge] {
        challengeService.fetchAllCompletions()
    }

    private func journalItems(from completions: [CompletedChallenge], matching query: String? = nil) -> [JournalDisplayItem] {
        let challenges = challengeService.loadChallenges()
        let challengeMap = Dictionary(challenges.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let lowered = query?.lowercased()

        return completions
            .sorted { $0.completedDate > $1.completedDate }
            .compactMap { completion in
                guard let challenge = challengeMap[completion.challengeId],
                      let journal = completion.journalEntry,
                      !journal.isEmpty else { return nil }
                if let lowered {
                    let matchesText = journal.lowercased().contains(lowered)
                    let matchesTitle = challenge.title.lowercased().contains(lowered)
                    guard matchesText || matchesTitle else { return nil }
                }
                return JournalDisplayItem(
                    id: completion.id,
                    challengeId: completion.challengeId,
                    challengeTitle: challenge.title,
                    category: challenge.category,
                    date: completion.completedDate,
                    journalText: journal,
                    scriptureReference: challenge.scriptureReference
                )
            }
    }
}
