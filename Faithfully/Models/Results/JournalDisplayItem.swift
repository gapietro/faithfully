import Foundation

struct JournalDisplayItem: Identifiable, Equatable {
    let id: UUID
    let challengeId: String
    let challengeTitle: String
    let category: ChallengeCategory
    let date: Date
    let journalText: String
    let scriptureReference: String
}
