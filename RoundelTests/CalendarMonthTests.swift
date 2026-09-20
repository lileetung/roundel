import XCTest
@testable import Roundel

final class CalendarMonthTests: XCTestCase {
    private let calendar = TestCalendar.sundayFirstUTC

    func testLeapYearFebruaryContainsTwentyNineDays() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2024, month: 2, day: 10)))
        let month = CalendarMonth(containing: date, calendar: calendar)
        let dates = month.cells.compactMap { $0 }

        XCTAssertEqual(dates.count, 29)
        XCTAssertEqual(calendar.component(.day, from: try XCTUnwrap(dates.last)), 29)
    }

    func testRowsAlwaysContainSevenCells() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))
        let month = CalendarMonth(containing: date, calendar: calendar)

        XCTAssertEqual(month.cells.count % 7, 0)
    }

    func testMovingAcrossYearBoundary() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 12, day: 15)))
        let nextMonth = CalendarMonth(containing: date, calendar: calendar).moved(by: 1)

        XCTAssertEqual(calendar.component(.year, from: nextMonth.startDate), 2027)
        XCTAssertEqual(calendar.component(.month, from: nextMonth.startDate), 1)
    }

    func testTitleUsesFixedNumericFormat() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 15)))
        let month = CalendarMonth(containing: date, calendar: calendar)

        XCTAssertEqual(month.title, "2026/09")
    }

    func testDayIDIsStableAndPadded() throws {
        let date = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 2, day: 3)))

        XCTAssertEqual(DayID(date: date, calendar: calendar).key, "2026-02-03")
    }
}
