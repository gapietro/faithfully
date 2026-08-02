import Foundation
import SwiftData

/// Schema history for the local store.
///
/// V1 identified a completed day by an absolute `Date`. V2 adds `dayKey`, the
/// frozen civil day (see `CivilDay`), and backfills it from the V1 instant using
/// the calendar in force at migration time — the same interpretation V1 itself
/// would have produced on that device, so nothing shifts underneath an existing
/// user. From V2 on, the day never moves again.
///
/// The V1 models are nested and named exactly as the originals. SwiftData
/// matches a store to a version by entity name and shape, so a renamed or
/// re-shaped stand-in (`CompletedChallengeV1`, or the same fields with default
/// values the original lacked) is not recognised and the store fails to open
/// with "Cannot use staged migration with an unknown model version".
enum FaithfullySchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [UserProfile.self, CompletedChallenge.self, EarnedBadge.self]
    }

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

    @Model
    final class UserProfile {
        var id: UUID
        var displayName: String
        var startDate: Date
        var preferredTranslation: BibleTranslation
        var morningNotificationTime: Date
        var eveningReminderTime: Date
        var morningNotificationsEnabled: Bool
        var eveningRemindersEnabled: Bool
        var streakWarningsEnabled: Bool
        var badgeNotificationsEnabled: Bool
        var darkModePreference: DarkModePreference

        init(
            id: UUID = UUID(),
            displayName: String = "",
            startDate: Date = .now,
            preferredTranslation: BibleTranslation = .web,
            morningNotificationTime: Date = .now,
            eveningReminderTime: Date = .now,
            morningNotificationsEnabled: Bool = true,
            eveningRemindersEnabled: Bool = true,
            streakWarningsEnabled: Bool = true,
            badgeNotificationsEnabled: Bool = true,
            darkModePreference: DarkModePreference = .system
        ) {
            self.id = id
            self.displayName = displayName
            self.startDate = startDate
            self.preferredTranslation = preferredTranslation
            self.morningNotificationTime = morningNotificationTime
            self.eveningReminderTime = eveningReminderTime
            self.morningNotificationsEnabled = morningNotificationsEnabled
            self.eveningRemindersEnabled = eveningRemindersEnabled
            self.streakWarningsEnabled = streakWarningsEnabled
            self.badgeNotificationsEnabled = badgeNotificationsEnabled
            self.darkModePreference = darkModePreference
        }
    }

    @Model
    final class EarnedBadge {
        var id: UUID
        var badgeName: String
        var badgeType: BadgeType
        var category: ChallengeCategory?
        var threshold: Int
        var earnedDate: Date

        init(
            id: UUID = UUID(),
            badgeName: String,
            badgeType: BadgeType,
            category: ChallengeCategory? = nil,
            threshold: Int,
            earnedDate: Date = .now
        ) {
            self.id = id
            self.badgeName = badgeName
            self.badgeType = badgeType
            self.category = category
            self.threshold = threshold
            self.earnedDate = earnedDate
        }
    }
}

enum FaithfullySchemaV2: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(2, 0, 0) }

    static var models: [any PersistentModel.Type] {
        [UserProfile.self, CompletedChallenge.self, EarnedBadge.self]
    }
}

enum FaithfullyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [FaithfullySchemaV1.self, FaithfullySchemaV2.self]
    }

    static var stages: [MigrationStage] { [v1ToV2] }

    /// Custom rather than lightweight: adding the column is mechanical, but
    /// *populating* it is the whole point. A lightweight migration would leave
    /// every existing completion with `dayKey == 0`, which reads as the year
    /// zero and would drop the user's entire history out of every query.
    static let v1ToV2 = MigrationStage.custom(
        fromVersion: FaithfullySchemaV1.self,
        toVersion: FaithfullySchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            try backfillDayKeys(in: context)
        }
    )

    /// Idempotent, and safe to run outside a migration. It is also called on
    /// every launch: a store that was created before the migration plan existed
    /// can arrive at V2 without passing through the stage, and an unbackfilled
    /// row would silently vanish from every query.
    @discardableResult
    static func backfillDayKeys(in context: ModelContext) throws -> Int {
        let stale = try context.fetch(FetchDescriptor<CompletedChallenge>(
            predicate: #Predicate { $0.dayKey == 0 }
        ))
        guard !stale.isEmpty else { return 0 }
        for completion in stale {
            completion.dayKey = CivilDay.key(for: completion.scheduledDate)
        }
        try context.save()
        return stale.count
    }
}
