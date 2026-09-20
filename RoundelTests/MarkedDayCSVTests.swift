import XCTest
@testable import Roundel

final class MarkedDayCSVTests: XCTestCase {
    private let reference = Date(timeIntervalSince1970: 1_789_294_951) // 2026-09-13T10:22:31Z

    func testEncodeWritesHeaderAndSortsByDay() {
        let csv = MarkedDayCSV.encode([
            MarkedDayCSV.Row(dayKey: "2026-09-18", markedAt: reference),
            MarkedDayCSV.Row(dayKey: "2026-09-13", markedAt: reference),
        ])

        XCTAssertEqual(csv, """
        date,marked_at
        2026-09-13,2026-09-13T10:22:31Z
        2026-09-18,2026-09-13T10:22:31Z

        """)
    }

    func testDecodeRoundTripsAnEncodedFile() throws {
        let rows = [
            MarkedDayCSV.Row(dayKey: "2026-01-03", markedAt: reference),
            MarkedDayCSV.Row(dayKey: "2026-09-13", markedAt: reference),
        ]

        XCTAssertEqual(try MarkedDayCSV.decode(MarkedDayCSV.encode(rows)), rows)
    }

    func testDecodeAcceptsDateOnlyRowsAndStampsThemWithImportTime() throws {
        let importedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let rows = try MarkedDayCSV.decode("2026-09-13\n2026-09-14\n", importedAt: importedAt)

        XCTAssertEqual(rows, [
            MarkedDayCSV.Row(dayKey: "2026-09-13", markedAt: importedAt),
            MarkedDayCSV.Row(dayKey: "2026-09-14", markedAt: importedAt),
        ])
    }

    func testDecodeToleratesBOMWindowsLineEndingsAndBlankLines() throws {
        let text = "\u{FEFF}date,marked_at\r\n2026-09-13,2026-09-13T10:22:31Z\r\n\r\n"
        let rows = try MarkedDayCSV.decode(text)

        XCTAssertEqual(rows, [MarkedDayCSV.Row(dayKey: "2026-09-13", markedAt: reference)])
    }

    func testDecodeNormalisesHandTypedDates() throws {
        let rows = try MarkedDayCSV.decode("2026-9-3\n", importedAt: reference)

        XCTAssertEqual(rows.map(\.dayKey), ["2026-09-03"])
    }

    func testDecodeCollapsesDuplicateDaysToTheFirstOccurrence() throws {
        let text = """
        date,marked_at
        2026-09-13,2026-09-13T10:22:31Z
        2026-09-13,2027-01-01T00:00:00Z
        """

        XCTAssertEqual(try MarkedDayCSV.decode(text), [
            MarkedDayCSV.Row(dayKey: "2026-09-13", markedAt: reference),
        ])
    }

    func testDecodeRejectsACalendarDayThatDoesNotExist() {
        XCTAssertThrowsError(try MarkedDayCSV.decode("2026-02-30\n")) { error in
            XCTAssertEqual(error as? MarkedDayCSV.Failure, .invalidDate(line: 1, value: "2026-02-30"))
        }
    }

    func testDecodeReportsTheOffendingLineNumber() {
        let text = """
        date,marked_at
        2026-09-13,2026-09-13T10:22:31Z
        nonsense
        """

        XCTAssertThrowsError(try MarkedDayCSV.decode(text)) { error in
            XCTAssertEqual(error as? MarkedDayCSV.Failure, .invalidDate(line: 3, value: "nonsense"))
        }
    }

    func testDecodeRejectsAnInvalidTimestamp() {
        XCTAssertThrowsError(try MarkedDayCSV.decode("2026-09-13,yesterday\n")) { error in
            XCTAssertEqual(error as? MarkedDayCSV.Failure, .invalidTimestamp(line: 1, value: "yesterday"))
        }
    }

    func testDecodeRejectsTooManyColumns() {
        XCTAssertThrowsError(try MarkedDayCSV.decode("2026-09-13,2026-09-13T10:22:31Z,extra\n")) { error in
            XCTAssertEqual(error as? MarkedDayCSV.Failure, .malformedRow(line: 1))
        }
    }

    func testDecodeRejectsAFileWithNothingInIt() {
        XCTAssertThrowsError(try MarkedDayCSV.decode("\n\n")) { error in
            XCTAssertEqual(error as? MarkedDayCSV.Failure, .emptyFile)
        }
    }

    func testDecodeAcceptsAHeaderOnlyFileAsAnEmptyImport() throws {
        XCTAssertEqual(try MarkedDayCSV.decode("date,marked_at\n"), [])
    }
}
