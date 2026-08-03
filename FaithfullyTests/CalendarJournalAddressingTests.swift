import XCTest
import SwiftData
@testable import Faithfully

/// Split out of CalendarViewModelTests: addressing a day's journal entry for
/// editing is a subject in its own right, and the combined class had outgrown
/// the length the linter enforces.
final class CalendarJournalAddressingTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var badgeService: BadgeService!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        badgeService = BadgeService(modelContext: context)
    }

    private func makeService(
        today: Date,
        enrolledOn: Date = Date.from(year: 2020, month: 1, day: 1)
    ) throws -> ChallengeService {
        try ChallengeService(
            modelContext: context,
            challenges: challenges,
            badgeService: badgeService,
            enrollmentDate: enrolledOn,
            dateProvider: { today }
        )
    }

    // MARK: - Addressing an entry for editing

    func testCompletedDayCarriesItsCompletionIdentifier() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        let challenge = service.challengeForDate(today)
        _ = try service.completeChallenge(challenge, on: today, journal: "wrote this")

        let vm = CalendarViewModel(challengeService: service, today: today)
        let day15 = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        })

        let stored = try XCTUnwrap(context.fetch(FetchDescriptor<CompletedChallenge>()).first)
        XCTAssertEqual(day15.completionID, stored.id,
                       "Day detail cannot edit an entry it cannot name")
    }

    func testCompletedDayWithNoReflectionStillCarriesItsIdentifier() throws {
        // This is how "add a reflection later" is possible at all.
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        _ = try service.completeChallenge(service.challengeForDate(today), on: today, journal: nil)

        let vm = CalendarViewModel(challengeService: service, today: today)
        let day15 = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        })

        XCTAssertNil(day15.journalEntry)
        XCTAssertNotNil(day15.completionID)
    }

    func testUncompletedDayHasNoCompletionIdentifier() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        let vm = CalendarViewModel(challengeService: service, today: today)

        let day15 = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        })
        XCTAssertNil(day15.completionID)
    }

    func testUpdatingAJournalRefreshesTheGrid() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        _ = try service.completeChallenge(service.challengeForDate(today), on: today, journal: "before")

        let vm = CalendarViewModel(challengeService: service, today: today)
        let id = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        }?.completionID)

        XCTAssertEqual(vm.updateJournal(entryID: id, to: "after"), .saved)

        let refreshed = vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        }
        XCTAssertEqual(refreshed?.journalEntry, "after",
                       "The grid must reflect the edit without a relaunch")
    }

    func testClearingAJournalKeepsTheDayCompleted() throws {
        let today = Date.from(year: 2026, month: 4, day: 15)
        let service = try makeService(today: today)
        _ = try service.completeChallenge(service.challengeForDate(today), on: today, journal: "gone soon")

        let vm = CalendarViewModel(challengeService: service, today: today)
        let id = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        }?.completionID)

        XCTAssertEqual(vm.updateJournal(entryID: id, to: nil), .saved)

        let refreshed = try XCTUnwrap(vm.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 15
        })
        XCTAssertNil(refreshed.journalEntry)
        XCTAssertEqual(refreshed.status, .completed,
                       "Clearing a reflection must not un-complete the day")
        XCTAssertEqual(refreshed.status.accessibilityDescription, "Completed")
    }
}
