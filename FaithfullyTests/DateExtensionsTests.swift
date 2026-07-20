import XCTest
@testable import Faithfully

final class DateExtensionsTests: XCTestCase {

    func testFromBuildsExpectedDate() {
        let date = Date.from(year: 2026, month: 6, day: 15)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 6)
        XCTAssertEqual(components.day, 15)
    }

    func testAddingDaysCrossesMonthBoundary() {
        let jan31 = Date.from(year: 2026, month: 1, day: 31)
        let next = jan31.addingDays(1)
        let components = Calendar.current.dateComponents([.month, .day], from: next)
        XCTAssertEqual(components.month, 2)
        XCTAssertEqual(components.day, 1)
    }

    func testAddingDaysCrossesYearBoundary() {
        let dec31 = Date.from(year: 2026, month: 12, day: 31)
        let next = dec31.addingDays(1)
        let components = Calendar.current.dateComponents([.year, .month, .day], from: next)
        XCTAssertEqual(components.year, 2027)
        XCTAssertEqual(components.month, 1)
        XCTAssertEqual(components.day, 1)
    }

    func testAddingDaysHandlesLeapDay() {
        // 2028 is a leap year
        let feb28Leap = Date.from(year: 2028, month: 2, day: 28)
        let leapNext = Calendar.current.dateComponents([.month, .day], from: feb28Leap.addingDays(1))
        XCTAssertEqual(leapNext.month, 2)
        XCTAssertEqual(leapNext.day, 29)

        // 2026 is not
        let feb28 = Date.from(year: 2026, month: 2, day: 28)
        let next = Calendar.current.dateComponents([.month, .day], from: feb28.addingDays(1))
        XCTAssertEqual(next.month, 3)
        XCTAssertEqual(next.day, 1)
    }

    func testStartOfDayZeroesTimeComponents() {
        let date = Date.from(year: 2026, month: 6, day: 15) // built at noon
        let start = date.startOfDay
        let components = Calendar.current.dateComponents([.hour, .minute, .second, .day], from: start)
        XCTAssertEqual(components.hour, 0)
        XCTAssertEqual(components.minute, 0)
        XCTAssertEqual(components.second, 0)
        XCTAssertEqual(components.day, 15)
    }
}
