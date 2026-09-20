import XCTest
@testable import Roundel

final class YearGridTests: XCTestCase {
    private let calendar = TestCalendar.sundayFirstUTC

    func testCommonYearStartingMidWeek() throws {
        // 2026-01-01 is a Thursday.
        let grid = try XCTUnwrap(YearGrid(year: 2026, calendar: calendar))

        XCTAssertEqual(grid.dayCount, 365)
        XCTAssertEqual(grid.leadingBlanks, 4)
        XCTAssertEqual(grid.columnCount, 53)
    }

    func testLeapYearNeedsFiftyFourColumns() throws {
        // 2028-01-01 is a Saturday, the widest a year gets: 6 blanks plus 366 days.
        let grid = try XCTUnwrap(YearGrid(year: 2028, calendar: calendar))

        XCTAssertEqual(grid.dayCount, 366)
        XCTAssertEqual(grid.leadingBlanks, 6)
        XCTAssertEqual(grid.columnCount, 54)
    }

    func testNoYearEverExceedsTheReservedColumnCapacity() throws {
        for year in 2000...2100 {
            let grid = try XCTUnwrap(YearGrid(year: year, calendar: calendar))
            XCTAssertLessThanOrEqual(grid.columnCount, YearDotGridView.columnCapacity, "year \(year)")
        }
    }

    func testFirstDayLandsOnItsWeekdayRow() throws {
        let grid = try XCTUnwrap(YearGrid(year: 2026, calendar: calendar))

        XCTAssertEqual(grid.cell(forDayOfYear: 1).column, 0)
        XCTAssertEqual(grid.cell(forDayOfYear: 1).row, 4) // Thursday
    }

    func testCellAndDayOfYearRoundTrip() throws {
        let grid = try XCTUnwrap(YearGrid(year: 2026, calendar: calendar))

        for dayOfYear in 1...grid.dayCount {
            let cell = grid.cell(forDayOfYear: dayOfYear)
            XCTAssertEqual(grid.dayOfYear(atColumn: cell.column, row: cell.row), dayOfYear)
        }
    }

    func testBlankCellsOutsideTheYearHaveNoDay() throws {
        let grid = try XCTUnwrap(YearGrid(year: 2026, calendar: calendar))

        // The four cells above January 1st.
        for row in 0..<4 {
            XCTAssertNil(grid.dayOfYear(atColumn: 0, row: row))
        }
        XCTAssertNil(grid.dayOfYear(atColumn: grid.columnCount, row: 0))
        XCTAssertNil(grid.dayOfYear(atColumn: 0, row: 7))
    }

    func testDayKeysMatchTheCalendarDays() throws {
        let grid = try XCTUnwrap(YearGrid(year: 2026, calendar: calendar))

        XCTAssertEqual(grid.dayKey(dayOfYear: 1), "2026-01-01")
        XCTAssertEqual(grid.dayKey(dayOfYear: 365), "2026-12-31")
        XCTAssertNil(grid.dayKey(dayOfYear: 366))
    }

    func testLeapDayIsPresentAndCorrectlyKeyed() throws {
        let grid = try XCTUnwrap(YearGrid(year: 2028, calendar: calendar))

        XCTAssertEqual(grid.dayKey(dayOfYear: 60), "2028-02-29")
        XCTAssertEqual(grid.dayKey(dayOfYear: 366), "2028-12-31")
    }

    func testMonthTicksAdvanceAcrossTheGrid() throws {
        let grid = try XCTUnwrap(YearGrid(year: 2026, calendar: calendar))
        let columns = grid.monthColumns

        XCTAssertEqual(columns.count, 12)
        XCTAssertEqual(columns.first?.column, 0)
        XCTAssertEqual(columns.map(\.column), columns.map(\.column).sorted())
        XCTAssertLessThan(try XCTUnwrap(columns.last?.column), grid.columnCount)
    }
}
