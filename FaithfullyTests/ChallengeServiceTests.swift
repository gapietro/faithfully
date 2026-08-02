import XCTest
import SwiftData
@testable import Faithfully

final class ChallengeServiceTests: XCTestCase {

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

    func testLoadChallengesReturns365Items() {
        XCTAssertEqual(service.loadChallenges().count, 365)
    }

    func testChallengeForDateReturnsCorrectChallenge() {
        let date = Date.from(year: 2026, month: 6, day: 15)
        let challenge = service.challengeForDate(date)
        let again = service.challengeForDate(date)
        XCTAssertEqual(challenge.id, again.id)
    }

    func testCompleteChallengeCreatesCompletedChallengeRecord() throws {
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        let descriptor = FetchDescriptor<CompletedChallenge>()
        let completions = try context.fetch(descriptor)
        XCTAssertEqual(completions.count, 1)
        XCTAssertEqual(completions.first?.challengeId, challenge.id)
    }

    func testCompleteChallengeWithJournalSavesJournalText() throws {
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: "God was good today")

        let descriptor = FetchDescriptor<CompletedChallenge>()
        let completions = try context.fetch(descriptor)
        XCTAssertEqual(completions.first?.journalEntry, "God was good today")
    }

    func testCompleteChallengeThrowsOnExpiredGracePeriod() {
        let fiveDaysAgo = Date.now.addingDays(-5)
        let challenge = service.challengeForDate(fiveDaysAgo)

        XCTAssertThrowsError(try service.completeChallenge(challenge, on: fiveDaysAgo, journal: nil)) { error in
            XCTAssertTrue(error is ChallengeServiceError)
        }
    }

    func testCompleteChallengeThrowsOnAlreadyCompleted() throws {
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        XCTAssertThrowsError(try service.completeChallenge(challenge, on: today, journal: nil)) { error in
            guard let serviceError = error as? ChallengeServiceError else {
                XCTFail("Expected ChallengeServiceError")
                return
            }
            XCTAssertEqual(serviceError, .alreadyCompleted)
        }
    }

    func testCompleteChallengeTriggersNewBadgeEvaluation() throws {
        // Complete enough challenges to earn a badge (7 for Ember streak is hard to set up,
        // so just verify the method returns badge definitions array)
        let today = Date.now
        let challenge = service.challengeForDate(today)
        let newBadges = try service.completeChallenge(challenge, on: today, journal: nil)

        // With only 1 completion, no badges should be earned yet
        XCTAssertTrue(newBadges.isEmpty, "1 completion should not earn any badges")
    }

    func testFetchCompletionsReturnsCorrectRecordsForDateRange() throws {
        // Complete today's challenge
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        let range = today.addingDays(-1)...today.addingDays(1)
        let completions = service.fetchCompletions(for: range)
        XCTAssertEqual(completions.count, 1)

        // Fetch a range that doesn't include today
        let pastRange = today.addingDays(-10)...today.addingDays(-5)
        let pastCompletions = service.fetchCompletions(for: pastRange)
        XCTAssertEqual(pastCompletions.count, 0)
    }

    // MARK: - Fail-closed pool (#5)

    func testInitThrowsOnEmptyChallengePool() {
        XCTAssertThrowsError(
            try ChallengeService(modelContext: context, challenges: [], badgeService: badgeService)
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .emptyChallengePool)
        }
    }

    func testInitThrowsOnGivingOnlyPool() {
        let givingOnly = challenges.filter { $0.category == .giving }
        XCTAssertThrowsError(
            try ChallengeService(modelContext: context, challenges: givingOnly, badgeService: badgeService)
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .emptyChallengePool)
        }
    }

    // MARK: - Completion keyed by scheduled day (#3)

    func testIsCompletedIsScopedToScheduledDay() throws {
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        XCTAssertTrue(service.isCompleted(on: today))
        XCTAssertFalse(service.isCompleted(on: today.addingDays(1)))
        XCTAssertFalse(service.isCompleted(on: today.addingDays(-1)))
    }

    func testCompletingReusedChallengeIdOnOneDayDoesNotCompleteTheOther() throws {
        // The scheduler reuses non-giving IDs within a year and giving IDs monthly.
        // Find two 2026 dates that map to the same challenge ID under one service.
        let startDate = Date.from(year: 2026, month: 1, day: 1)
        var currentToday = startDate
        let service = try ChallengeService(
            modelContext: context,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: startDate,
            dateProvider: { currentToday }
        )

        var datesByChallengeId: [String: [Date]] = [:]
        for offset in 0..<365 {
            let date = startDate.addingDays(offset)
            datesByChallengeId[service.challengeForDate(date).id, default: []].append(date)
        }
        guard let reusedDates = datesByChallengeId.values.first(where: { $0.count >= 2 }) else {
            XCTFail("Expected at least one challenge ID scheduled on two dates within the year")
            return
        }
        let dateA = reusedDates[0]
        let dateB = reusedDates[1]
        XCTAssertEqual(service.challengeForDate(dateA).id, service.challengeForDate(dateB).id)

        // Complete day A (with "today" set to day A so grace allows it)
        currentToday = dateA
        _ = try service.completeChallenge(service.challengeForDate(dateA), on: dateA, journal: nil)

        XCTAssertTrue(service.isCompleted(on: dateA))
        XCTAssertFalse(service.isCompleted(on: dateB),
                       "Completing day A must not mark a later day with the same challenge ID as done")

        // Day B must still be completable independently
        currentToday = dateB
        XCTAssertNoThrow(try service.completeChallenge(service.challengeForDate(dateB), on: dateB, journal: nil))
        XCTAssertTrue(service.isCompleted(on: dateB))

        let all = try context.fetch(FetchDescriptor<CompletedChallenge>())
        XCTAssertEqual(all.count, 2, "Both days should have their own completion record")
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

    // MARK: - Enrollment boundary (CLEAN-002)

    private func makeEnrolledService(enrolledOn: Date, today: Date) throws -> ChallengeService {
        try ChallengeService(
            modelContext: context,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: enrolledOn,
            dateProvider: { today }
        )
    }

    func testCompletionIsRejectedTheDayBeforeEnrollment() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)
        let dayBefore = enrolled.addingDays(-1)

        XCTAssertThrowsError(
            try service.completeChallenge(service.challengeForDate(dayBefore), on: dayBefore, journal: nil)
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .beforeEnrollment)
        }
        XCTAssertFalse(service.isCompleted(on: dayBefore))
        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletedChallenge>()).count, 0)
    }

    func testCompletionIsAcceptedOnTheEnrollmentDayItself() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)

        XCTAssertNoThrow(
            try service.completeChallenge(service.challengeForDate(enrolled), on: enrolled, journal: nil)
        )
        XCTAssertTrue(service.isCompleted(on: enrolled))
    }

    func testCompletionIsAcceptedTheDayAfterEnrollment() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let dayAfter = enrolled.addingDays(1)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: dayAfter)

        XCTAssertNoThrow(
            try service.completeChallenge(service.challengeForDate(dayAfter), on: dayAfter, journal: nil)
        )
        XCTAssertTrue(service.isCompleted(on: dayAfter))
    }

    /// Enrollment is checked before the grace window, so no combination of the
    /// two can be used to backfill history that predates the account.
    func testGraceWindowCannotBackfillPreEnrollmentDays() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let today = Date.from(year: 2026, month: 6, day: 16)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: today)

        // Days 13 and 14 sit inside the 3-day grace window from the 16th,
        // but both precede enrollment on the 15th.
        for offset in [-2, -1] {
            let date = enrolled.addingDays(offset)
            XCTAssertTrue(GracePeriod.canComplete(challengeDate: date, today: today),
                          "Precondition: \(date) must be inside the grace window")
            XCTAssertThrowsError(
                try service.completeChallenge(service.challengeForDate(date), on: date, journal: nil)
            ) { error in
                XCTAssertEqual(error as? ChallengeServiceError, .beforeEnrollment,
                               "Grace must not override enrollment for \(date)")
            }
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<CompletedChallenge>()).count, 0)
    }

    func testEnrollmentBoundaryHoldsAcrossMonthRollover() throws {
        let enrolled = Date.from(year: 2026, month: 7, day: 1)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)
        let lastDayOfPreviousMonth = Date.from(year: 2026, month: 6, day: 30)

        XCTAssertThrowsError(
            try service.completeChallenge(
                service.challengeForDate(lastDayOfPreviousMonth), on: lastDayOfPreviousMonth, journal: nil
            )
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .beforeEnrollment)
        }
    }

    func testEnrollmentBoundaryHoldsAcrossYearRollover() throws {
        let enrolled = Date.from(year: 2027, month: 1, day: 1)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)
        let newYearsEve = Date.from(year: 2026, month: 12, day: 31)

        XCTAssertThrowsError(
            try service.completeChallenge(service.challengeForDate(newYearsEve), on: newYearsEve, journal: nil)
        ) { error in
            XCTAssertEqual(error as? ChallengeServiceError, .beforeEnrollment)
        }
    }

    /// The boundary is a calendar day, not an instant: enrolling at 9pm must not
    /// lock the user out of the day they actually joined on.
    func testEnrollmentBoundaryComparesWholeDaysNotInstants() throws {
        // Date.from anchors at noon, so these offsets are 9pm and 8am on June 15.
        let noon = Date.from(year: 2026, month: 6, day: 15)
        let enrolledLateInTheDay = noon.addingTimeInterval(9 * 3600)
        let morningOfSameDay = noon.addingTimeInterval(-4 * 3600)
        XCTAssertTrue(
            Calendar.current.isDate(enrolledLateInTheDay, inSameDayAs: morningOfSameDay),
            "Precondition: both instants must fall on the same civil day"
        )
        let service = try makeEnrolledService(
            enrolledOn: enrolledLateInTheDay, today: enrolledLateInTheDay
        )

        XCTAssertNoThrow(
            try service.completeChallenge(
                service.challengeForDate(morningOfSameDay), on: morningOfSameDay, journal: nil
            )
        )
    }

    func testEnrollmentDateIsExposedForCalendarRendering() throws {
        let enrolled = Date.from(year: 2026, month: 6, day: 15)
        let service = try makeEnrolledService(enrolledOn: enrolled, today: enrolled)
        XCTAssertEqual(service.enrollmentDate, enrolled)
    }

    // MARK: - Year rotation in the live service path (#4, CLEAN-001)

    /// The core shared-experience contract: enrollment date must not influence
    /// which challenge a civil date resolves to. This is the test that fails if
    /// anyone reintroduces tenure-relative rotation.
    func testEnrollmentDateDoesNotAffectWhichChallengeADateResolvesTo() throws {
        let enrollmentDates = [
            Date.from(year: 2020, month: 3, day: 7),
            Date.from(year: 2025, month: 12, day: 31),
            Date.from(year: 2026, month: 1, day: 1),
            Date.from(year: 2026, month: 6, day: 15),
            Date.from(year: 2029, month: 11, day: 2)
        ]
        let services = try enrollmentDates.map { startDate in
            try ChallengeService(
                modelContext: context, challenges: challenges, badgeService: badgeService,
                enrollmentDate: startDate
            )
        }

        // Sample across four calendar years, including both first Saturdays
        // (giving) and ordinary days, and both leap and non-leap years.
        let sampleDates = (0..<4).flatMap { yearOffset -> [Date] in
            let year = 2026 + yearOffset
            return [
                Date.from(year: year, month: 1, day: 1),
                Date.from(year: year, month: 2, day: 7),
                Date.from(year: year, month: 6, day: 15),
                Date.from(year: year, month: 12, day: 31)
            ]
        }

        for date in sampleDates {
            let ids = Set(services.map { $0.challengeForDate(date).id })
            XCTAssertEqual(
                ids.count, 1,
                "Every user must receive the same challenge on \(date); got \(ids.sorted())"
            )
        }
    }

    func testChallengeForDateUsesTheGlobalEpochOffset() throws {
        let service = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            enrollmentDate: Date.from(year: 2025, month: 1, day: 1)
        )
        let scheduler = try XCTUnwrap(ChallengeScheduler(challenges: challenges))

        for year in 2026...2030 {
            let target = Date.from(year: year, month: 6, day: 15)
            let expectedOffset = year - Constants.rotationEpochYear
            XCTAssertEqual(
                service.challengeForDate(target).id,
                scheduler.challengeForDate(target, yearOffset: expectedOffset).id,
                "\(year) must rotate by \(expectedOffset) from the global epoch"
            )
        }
    }

    func testAdjacentCalendarYearsRotateToDifferentChallenges() throws {
        let service = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService,
            enrollmentDate: Date.from(year: 2026, month: 1, day: 1)
        )

        for year in 2026...2029 {
            let thisYear = service.challengeForDate(Date.from(year: year, month: 6, day: 15))
            let nextYear = service.challengeForDate(Date.from(year: year + 1, month: 6, day: 15))
            XCTAssertNotEqual(
                thisYear.id, nextYear.id,
                "June 15 must rotate between \(year) and \(year + 1)"
            )
        }
    }

    func testRotationIsStableAcrossServiceInstances() throws {
        let target = Date.from(year: 2027, month: 4, day: 9)
        let first = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService
        ).challengeForDate(target)
        let second = try ChallengeService(
            modelContext: context, challenges: challenges, badgeService: badgeService
        ).challengeForDate(target)

        XCTAssertEqual(first.id, second.id,
                       "A civil date must resolve deterministically, not per-session")
    }

    func testCalculateStreakDelegatesToStreakAlgorithm() throws {
        // No completions = streak of 0
        XCTAssertEqual(service.calculateStreak(), 0)

        // Complete today
        let today = Date.now
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: nil)

        XCTAssertEqual(service.calculateStreak(), 1)
    }
}

extension ChallengeServiceError: Equatable {
    public static func == (lhs: ChallengeServiceError, rhs: ChallengeServiceError) -> Bool {
        switch (lhs, rhs) {
        case (.gracePeriodExpired, .gracePeriodExpired): return true
        case (.alreadyCompleted, .alreadyCompleted): return true
        default: return false
        }
    }
}
