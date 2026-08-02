import Foundation

enum Constants {
    /// Fixed global anchor for the annual challenge rotation. Every install shares
    /// this epoch, which is what makes the shared-experience promise true: two users
    /// who enrolled years apart still see the same challenge on the same civil date.
    /// Changing this value reshuffles the schedule for everyone — treat it as frozen.
    static let rotationEpochYear = 2026

    /// Default reminder times for a new profile. `UserProfile` reads these, so
    /// the value lives in one place rather than as a literal in an initialiser.
    static let defaultMorningHour = 7
    static let defaultEveningHour = 20

    static let maxJournalLength = 2000
}
