import XCTest
import SwiftData
@testable import Faithfully

/// Split out of ChallengeServiceTests: the journal contract is a subject in
/// its own right, and the combined class had outgrown the length the linter
/// enforces.
final class ChallengeServiceJournalTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var badgeService: BadgeService!
    var service: ChallengeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        badgeService = BadgeService(modelContext: context)
        service = try ChallengeService(modelContext: context, challenges: challenges, badgeService: badgeService)
    }
    // MARK: - Journal length is a contract, not a silent trim (CLEAN-003)

    private func journal(ofLength length: Int) -> String {
        String(repeating: "a", count: length)
    }

    func testJournalOneUnderTheLimitIsStoredWhole() throws {
        let text = journal(ofLength: Constants.maxJournalLength - 1)
        let today = Date.now
        _ = try service.completeChallenge(service.challengeForDate(today), on: today, journal: text)

        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<CompletedChallenge>()).first)
        XCTAssertEqual(stored.journalEntry?.count, Constants.maxJournalLength - 1)
        XCTAssertEqual(stored.journalEntry, text, "Nothing may be dropped below the limit")
    }

    func testJournalExactlyAtTheLimitIsStoredWhole() throws {
        let text = journal(ofLength: Constants.maxJournalLength)
        let today = Date.now
        _ = try service.completeChallenge(service.challengeForDate(today), on: today, journal: text)

        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<CompletedChallenge>()).first)
        XCTAssertEqual(stored.journalEntry?.count, Constants.maxJournalLength)
        XCTAssertEqual(stored.journalEntry, text, "The limit itself is allowed, not trimmed")
    }

    func testJournalOneOverTheLimitIsRejectedAndNothingIsPersisted() throws {
        let text = journal(ofLength: Constants.maxJournalLength + 1)
        let today = Date.now

        XCTAssertThrowsError(
            try service.completeChallenge(service.challengeForDate(today), on: today, journal: text)
        ) { error in
            XCTAssertEqual(
                error as? ChallengeServiceError,
                .journalTooLong(limit: Constants.maxJournalLength, actual: Constants.maxJournalLength + 1)
            )
        }

        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletedChallenge>()).count, 0,
                       "A rejected journal must not leave a half-written completion behind")
        XCTAssertFalse(service.isCompleted(on: today),
                       "The day must remain incomplete so the user can retry")
    }

    /// The regression the audit reproduced: 2,001 characters used to persist as
    /// 2,000 with no warning, so the user believed the tail was saved.
    func testOverLimitJournalIsNeverSilentlyTruncated() throws {
        let text = journal(ofLength: Constants.maxJournalLength + 500)
        let today = Date.now

        XCTAssertThrowsError(
            try service.completeChallenge(service.challengeForDate(today), on: today, journal: text)
        )
        let stored = try context.fetch(FetchDescriptor<CompletedChallenge>())
        XCTAssertTrue(stored.isEmpty,
                      "No truncated copy may be written; got \(stored.first?.journalEntry?.count ?? 0) characters")
    }

    func testTrailingWhitespaceDoesNotPushAJournalOverTheLimit() throws {
        // Length is judged after trimming, so a user who ends with a newline
        // does not lose their reflection to an off-by-whitespace rejection.
        let text = journal(ofLength: Constants.maxJournalLength) + "\n   \n"
        let today = Date.now

        XCTAssertNoThrow(
            try service.completeChallenge(service.challengeForDate(today), on: today, journal: text)
        )
        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<CompletedChallenge>()).first)
        XCTAssertEqual(stored.journalEntry?.count, Constants.maxJournalLength)
    }

    func testJournalTooLongErrorReportsTheActualLength() throws {
        let actual = Constants.maxJournalLength + 137
        let today = Date.now

        XCTAssertThrowsError(
            try service.completeChallenge(
                service.challengeForDate(today), on: today, journal: journal(ofLength: actual)
            )
        ) { error in
            guard case .journalTooLong(let limit, let reported) = (error as? ChallengeServiceError) else {
                return XCTFail("Expected journalTooLong, got \(error)")
            }
            XCTAssertEqual(limit, Constants.maxJournalLength)
            XCTAssertEqual(reported, actual, "The user must be told how far over they are")
        }
    }
}
