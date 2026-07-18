import Foundation
import SwiftData

@Model
final class CompletedChallenge {
    var id: UUID
    var challengeId: String
    var challengeCategory: String
    var completedDate: Date
    var scheduledDate: Date
    var journalEntry: String?

    init(
        id: UUID = UUID(),
        challengeId: String,
        challengeCategory: String,
        completedDate: Date = .now,
        scheduledDate: Date,
        journalEntry: String? = nil
    ) {
        self.id = id
        self.challengeId = challengeId
        self.challengeCategory = challengeCategory
        self.completedDate = completedDate
        self.scheduledDate = scheduledDate
        self.journalEntry = journalEntry
    }
}
