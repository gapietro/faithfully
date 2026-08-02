import XCTest
import SwiftData
@testable import Faithfully

/// Exercises the V1 → V2 migration against a real on-disk store.
///
/// An in-memory container never migrates, so these have to write actual files.
/// Each test uses its own temporary directory and removes it afterwards.
final class CivilDayMigrationTests: XCTestCase {

    private var storeDirectory: URL!
    private var storeURL: URL!

    override func setUpWithError() throws {
        storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("faithfully-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        storeURL = storeDirectory.appendingPathComponent("test.store")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: storeDirectory)
    }

    private func makeV1Container() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(FaithfullySchemaV1.models),
            migrationPlan: nil,
            configurations: ModelConfiguration(schema: Schema(FaithfullySchemaV1.models), url: storeURL)
        )
    }

    private func makeV2Container() throws -> ModelContainer {
        try ModelContainer(
            for: Schema(FaithfullySchemaV2.models),
            migrationPlan: FaithfullyMigrationPlan.self,
            configurations: ModelConfiguration(schema: Schema(FaithfullySchemaV2.models), url: storeURL)
        )
    }

    // MARK: - Migration

    @MainActor
    func testV1StoreMigratesAndBackfillsEveryDayKey() throws {
        let scheduledDates = [
            Date.from(year: 2026, month: 1, day: 1),
            Date.from(year: 2026, month: 6, day: 15),
            Date.from(year: 2026, month: 12, day: 31)
        ]

        let v1 = try makeV1Container()
        for date in scheduledDates {
            v1.mainContext.insert(FaithfullySchemaV1.CompletedChallenge(
                challengeId: "challenge_1",
                challengeCategory: "prayer",
                completedDate: date,
                scheduledDate: date.startOfDay,
                journalEntry: "written under v1"
            ))
        }
        try v1.mainContext.save()

        let v2 = try makeV2Container()
        let migrated = try v2.mainContext.fetch(FetchDescriptor<CompletedChallenge>())

        XCTAssertEqual(migrated.count, scheduledDates.count, "No row may be lost in migration")
        XCTAssertTrue(
            migrated.allSatisfy { $0.dayKey != CompletedChallenge.unmigratedDayKey },
            "Every migrated row must carry a real civil day, not the unmigrated sentinel"
        )
        XCTAssertEqual(
            Set(migrated.map(\.dayKey)),
            Set(scheduledDates.map { CivilDay.key(for: $0) }),
            "Backfilled keys must match the days the V1 instants represented"
        )
    }

    @MainActor
    func testMigrationPreservesEveryOtherField() throws {
        let scheduled = Date.from(year: 2026, month: 6, day: 15)
        let completed = Date.from(year: 2026, month: 6, day: 16)

        let v1 = try makeV1Container()
        v1.mainContext.insert(FaithfullySchemaV1.CompletedChallenge(
            challengeId: "challenge_173",
            challengeCategory: "giving",
            completedDate: completed,
            scheduledDate: scheduled.startOfDay,
            journalEntry: "a reflection that must survive"
        ))
        try v1.mainContext.save()

        let v2 = try makeV2Container()
        let row = try XCTUnwrap(try v2.mainContext.fetch(FetchDescriptor<CompletedChallenge>()).first)

        XCTAssertEqual(row.challengeId, "challenge_173")
        XCTAssertEqual(row.challengeCategory, "giving")
        XCTAssertEqual(row.journalEntry, "a reflection that must survive")
        XCTAssertEqual(row.completedDate.timeIntervalSince1970, completed.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(row.scheduledDate.timeIntervalSince1970, scheduled.startOfDay.timeIntervalSince1970, accuracy: 1)
    }

    @MainActor
    func testMigratedStoreReopensWithoutRemigrating() throws {
        let v1 = try makeV1Container()
        let date = Date.from(year: 2026, month: 6, day: 15)
        v1.mainContext.insert(FaithfullySchemaV1.CompletedChallenge(
            challengeId: "c1", challengeCategory: "prayer",
            completedDate: date, scheduledDate: date.startOfDay
        ))
        try v1.mainContext.save()

        _ = try makeV2Container()
        let reopened = try makeV2Container()
        let rows = try reopened.mainContext.fetch(FetchDescriptor<CompletedChallenge>())

        XCTAssertEqual(rows.count, 1, "Reopening must not duplicate rows")
        XCTAssertEqual(rows.first?.dayKey, CivilDay.key(for: date))
    }

    @MainActor
    func testEmptyV1StoreMigratesCleanly() throws {
        _ = try makeV1Container()
        let v2 = try makeV2Container()
        XCTAssertEqual(try v2.mainContext.fetch(FetchDescriptor<CompletedChallenge>()).count, 0)
    }

    // MARK: - Backfill safety net

    func testBackfillRepairsRowsThatBypassedTheMigrationStage() throws {
        // A store created before the migration plan existed arrives at V2
        // directly, without passing through the stage.
        let container = try TestHelpers.makeModelContainer()
        let context = ModelContext(container)
        let date = Date.from(year: 2026, month: 6, day: 15)
        let orphan = CompletedChallenge(
            challengeId: "c1", challengeCategory: "prayer",
            completedDate: date, scheduledDate: date.startOfDay
        )
        orphan.dayKey = CompletedChallenge.unmigratedDayKey
        context.insert(orphan)
        try context.save()

        let repaired = try FaithfullyMigrationPlan.backfillDayKeys(in: context)

        XCTAssertEqual(repaired, 1)
        XCTAssertEqual(orphan.dayKey, CivilDay.key(for: date))
    }

    func testBackfillIsIdempotentAndLeavesGoodRowsAlone() throws {
        let container = try TestHelpers.makeModelContainer()
        let context = ModelContext(container)
        let date = Date.from(year: 2026, month: 6, day: 15)
        let healthy = CompletedChallenge(
            challengeId: "c1", challengeCategory: "prayer",
            completedDate: date, scheduledDate: date.startOfDay
        )
        context.insert(healthy)
        try context.save()
        let originalKey = healthy.dayKey

        XCTAssertEqual(try FaithfullyMigrationPlan.backfillDayKeys(in: context), 0)
        XCTAssertEqual(try FaithfullyMigrationPlan.backfillDayKeys(in: context), 0)
        XCTAssertEqual(healthy.dayKey, originalKey, "A healthy row must not be rewritten")
    }

    // MARK: - Rollback

    /// The recovery path if V2 has to be pulled: V1 must still be able to open
    /// the migrated file. `dayKey` is additive, so V1 simply ignores it — no
    /// data is lost, only the new column.
    @MainActor
    func testAV1BuildCanStillOpenAMigratedStore() throws {
        let date = Date.from(year: 2026, month: 6, day: 15)
        let v1 = try makeV1Container()
        v1.mainContext.insert(FaithfullySchemaV1.CompletedChallenge(
            challengeId: "c1", challengeCategory: "prayer",
            completedDate: date, scheduledDate: date.startOfDay,
            journalEntry: "must survive a rollback"
        ))
        try v1.mainContext.save()

        _ = try makeV2Container()

        let rolledBack = try makeV1Container()
        let rows = try rolledBack.mainContext.fetch(
            FetchDescriptor<FaithfullySchemaV1.CompletedChallenge>()
        )
        XCTAssertEqual(rows.count, 1, "A downgraded build must still read its own data")
        XCTAssertEqual(rows.first?.journalEntry, "must survive a rollback")
    }
}
