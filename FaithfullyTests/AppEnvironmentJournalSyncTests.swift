import XCTest
import SwiftData
@testable import Faithfully

/// Split out of `AppEnvironmentTests`: cross-tab journal sync is a subject in
/// its own right, and the combined class had outgrown the length the linter
/// enforces.
///
/// Final review C1: a reflection edited or deleted in one tab must reach the
/// other without the app being backgrounded and foregrounded in between.
/// Before the fix, `CalendarViewModel.updateJournal` and
/// `JourneyViewModel.updateJournal` each refreshed only their own view model —
/// a deletion made in Journey stayed visible in Calendar's open day detail,
/// and pressing Save from that stale panel would have written the deleted
/// text back.
final class AppEnvironmentJournalSyncTests: XCTestCase {

    var container: ModelContainer!
    var context: ModelContext!
    var challenges: [DailyChallenge]!
    var mockNotificationCenter: MockNotificationCenter!

    override func setUpWithError() throws {
        container = try TestHelpers.makeModelContainer()
        context = ModelContext(container)
        challenges = try TestHelpers.loadTestChallenges()
        mockNotificationCenter = MockNotificationCenter()
    }

    @discardableResult
    private func seedProfile(enrolledOn: Date) throws -> UserProfile {
        let profile = UserProfile(startDate: enrolledOn)
        context.insert(profile)
        try context.save()
        return profile
    }

    private func makeEnvironment(today: Date) -> AppEnvironment {
        AppEnvironment(
            modelContext: context,
            loadChallenges: { self.challenges },
            notificationService: NotificationService(center: mockNotificationCenter),
            dateProvider: { today }
        )
    }

    /// Inserts a completion with a reflection directly, independent of the
    /// service graph under test — mirrors how `seedProfile` sets up state the
    /// environment must discover, not produce.
    @discardableResult
    private func seedCompletion(on date: Date, journal: String?) throws -> UUID {
        let challenge = challenges[0]
        let completion = CompletedChallenge(
            challengeId: challenge.id,
            challengeCategory: challenge.category.rawValue,
            completedDate: date,
            scheduledDate: date.startOfDay,
            journalEntry: journal
        )
        context.insert(completion)
        try context.save()
        return completion.id
    }

    /// Reproduces the finding directly: delete a reflection from Journey while
    /// Calendar's day detail is already open on that day, without backgrounding
    /// the app in between. Before the fix, Calendar's `selectedDay` kept the
    /// value it was constructed with, so the deleted text stayed visible and a
    /// subsequent Save from that stale panel would have written it back.
    func testDeletingAReflectionInJourneyClearsItInCalendarsOpenDetail() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        try seedProfile(enrolledOn: Date.from(year: 2026, month: 6, day: 1))
        let entryID = try seedCompletion(
            on: Date.from(year: 2026, month: 6, day: 10),
            journal: "a private confession"
        )
        let env = makeEnvironment(today: today)
        let services = try XCTUnwrap(env.services)

        let day = try XCTUnwrap(services.calendarViewModel.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 10
        })
        services.calendarViewModel.selectDay(day)
        XCTAssertEqual(services.calendarViewModel.selectedDay?.journalEntry, "a private confession")

        XCTAssertEqual(services.journeyViewModel.updateJournal(entryID: entryID, to: nil), .saved)

        XCTAssertNil(
            services.calendarViewModel.selectedDay?.journalEntry,
            "Calendar's open day detail must not still show text just deleted in Journey"
        )
        let dayAfter = try XCTUnwrap(services.calendarViewModel.calendarDays.first {
            Calendar.current.component(.day, from: $0.date) == 10
        })
        XCTAssertNil(dayAfter.journalEntry,
                     "Calendar's grid data must reflect the deletion without a relaunch")
    }

    /// The reverse direction: an edit made from the Calendar must reach Journey
    /// without a relaunch.
    func testEditingAReflectionInCalendarUpdatesJourneyWithoutRelaunch() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        try seedProfile(enrolledOn: Date.from(year: 2026, month: 6, day: 1))
        let entryID = try seedCompletion(on: Date.from(year: 2026, month: 6, day: 10), journal: "before")
        let env = makeEnvironment(today: today)
        let services = try XCTUnwrap(env.services)

        XCTAssertEqual(services.journeyViewModel.journalEntries.first?.journalText, "before")

        XCTAssertEqual(services.calendarViewModel.updateJournal(entryID: entryID, to: "after"), .saved)

        XCTAssertEqual(
            services.journeyViewModel.journalEntries.first?.journalText, "after",
            "Journey must reflect a reflection edited from the Calendar without a relaunch"
        )
    }

    /// A failed edit must not ripple to the other tab — there is nothing new to
    /// sync, and firing the callback anyway would just be wasted work hiding a
    /// latent re-entrancy bug.
    func testAFailedJournalEditDoesNotTriggerACrossTabRefresh() throws {
        let today = Date.from(year: 2026, month: 6, day: 15)
        try seedProfile(enrolledOn: Date.from(year: 2026, month: 6, day: 1))
        let entryID = try seedCompletion(on: Date.from(year: 2026, month: 6, day: 10), journal: "keep me")
        let env = makeEnvironment(today: today)
        let services = try XCTUnwrap(env.services)
        let overLimit = String(repeating: "a", count: Constants.maxJournalLength + 1)

        let result = services.journeyViewModel.updateJournal(entryID: entryID, to: overLimit)

        guard case .failed = result else {
            XCTFail("Expected the over-limit edit to fail, got \(result)")
            return
        }
        XCTAssertEqual(services.journeyViewModel.journalEntries.first?.journalText, "keep me")
    }
}
