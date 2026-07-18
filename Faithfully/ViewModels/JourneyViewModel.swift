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
        let farPast = Date.from(year: 2020, month: 1, day: 1)
        let farFuture = Date.from(year: 2030, month: 12, day: 31)
        let completions = challengeService.fetchCompletions(for: farPast...farFuture)
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

        // Journal entries — reverse chronological
        let challenges = challengeService.loadChallenges()
        let challengeMap = Dictionary(challenges.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        journalEntries = completions
            .filter { $0.journalEntry != nil && !$0.journalEntry!.isEmpty }
            .sorted { $0.completedDate > $1.completedDate }
            .compactMap { completion in
                guard let challenge = challengeMap[completion.challengeId],
                      let journal = completion.journalEntry else { return nil }
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

    func searchJournal(_ query: String) {
        guard !query.isEmpty else {
            refresh()
            return
        }
        let lowered = query.lowercased()
        let farPast = Date.from(year: 2020, month: 1, day: 1)
        let farFuture = Date.from(year: 2030, month: 12, day: 31)
        let completions = challengeService.fetchCompletions(for: farPast...farFuture)
        let challenges = challengeService.loadChallenges()
        let challengeMap = Dictionary(challenges.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        journalEntries = completions
            .filter { $0.journalEntry != nil && !$0.journalEntry!.isEmpty }
            .sorted { $0.completedDate > $1.completedDate }
            .compactMap { completion in
                guard let challenge = challengeMap[completion.challengeId],
                      let journal = completion.journalEntry else { return nil }
                let matchesText = journal.lowercased().contains(lowered)
                let matchesTitle = challenge.title.lowercased().contains(lowered)
                guard matchesText || matchesTitle else { return nil }
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
}
