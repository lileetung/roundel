import XCTest
@testable import Roundel

@MainActor
final class MarkStoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("roundel.csv")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testStartsEmptyWhenTheFileDoesNotExist() {
        let store = MarkStore(fileURL: fileURL)

        XCTAssertEqual(store.count, 0)
        XCTAssertNil(store.failure)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testTogglingWritesTheFile() throws {
        let store = MarkStore(fileURL: fileURL)
        store.toggle("2026-09-13")

        XCTAssertTrue(store.isMarked("2026-09-13"))
        let written = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(written.hasPrefix("date,marked_at\n2026-09-13,"), written)
    }

    func testTogglingTwiceRemovesTheDay() throws {
        let store = MarkStore(fileURL: fileURL)
        store.toggle("2026-09-13")
        store.toggle("2026-09-13")

        XCTAssertFalse(store.isMarked("2026-09-13"))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "date,marked_at\n")
    }

    func testMarksSurviveIntoAFreshStoreOverTheSameFile() {
        let first = MarkStore(fileURL: fileURL)
        first.toggle("2026-01-03")
        first.toggle("2026-09-13")

        let second = MarkStore(fileURL: fileURL)

        XCTAssertEqual(second.rows.map(\.dayKey), ["2026-01-03", "2026-09-13"])
        XCTAssertNil(second.failure)
    }

    func testMergeAddsOnlyDaysThatAreNotAlreadyMarked() {
        let store = MarkStore(fileURL: fileURL)
        store.toggle("2026-09-13")

        let result = store.merge([
            MarkedDayCSV.Row(dayKey: "2026-09-13", markedAt: .now),
            MarkedDayCSV.Row(dayKey: "2026-09-14", markedAt: .now),
        ])

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.alreadyMarked, 1)
        XCTAssertEqual(result.inFuture, 0)
        XCTAssertEqual(store.rows.map(\.dayKey), ["2026-09-13", "2026-09-14"])
    }

    func testMergeKeepsTheExistingMarkTime() throws {
        let store = MarkStore(fileURL: fileURL)
        store.toggle("2026-09-13")
        let original = try XCTUnwrap(store.marks["2026-09-13"])

        store.merge([MarkedDayCSV.Row(dayKey: "2026-09-13", markedAt: .distantPast)])

        XCTAssertEqual(store.marks["2026-09-13"], original)
    }

    // MARK: - The future-date rule

    func testAFutureDayCannotBeMarked() {
        let store = MarkStore(fileURL: fileURL, todayKey: { "2026-09-20" })

        store.toggle("2026-09-21")

        XCTAssertFalse(store.isMarked("2026-09-21"))
        XCTAssertEqual(store.count, 0)
    }

    func testTodayCanBeMarked() {
        let store = MarkStore(fileURL: fileURL, todayKey: { "2026-09-20" })

        store.toggle("2026-09-20")

        XCTAssertTrue(store.isMarked("2026-09-20"))
    }

    func testAPastDayCanBeMarked() {
        let store = MarkStore(fileURL: fileURL, todayKey: { "2026-09-20" })

        store.toggle("2026-09-19")

        XCTAssertTrue(store.isMarked("2026-09-19"))
    }

    func testImportDropsDaysThatHaveNotArrived() {
        let store = MarkStore(fileURL: fileURL, todayKey: { "2026-09-20" })

        let result = store.merge([
            MarkedDayCSV.Row(dayKey: "2026-09-19", markedAt: .now),
            MarkedDayCSV.Row(dayKey: "2026-12-25", markedAt: .now),
        ])

        XCTAssertEqual(result.added, 1)
        XCTAssertEqual(result.inFuture, 1)
        XCTAssertFalse(store.isMarked("2026-12-25"))
    }

    /// Marks made before the rule existed, or written in by hand, are dropped on
    /// the way in rather than lingering as circles nothing can clear.
    func testAFutureDateInTheFileIsDroppedWhenReading() throws {
        try "date,marked_at\n2026-09-19,2026-09-19T00:00:00Z\n2026-12-25,2026-01-01T00:00:00Z\n"
            .write(to: fileURL, atomically: true, encoding: .utf8)

        let store = MarkStore(fileURL: fileURL, todayKey: { "2026-09-20" })

        XCTAssertEqual(store.rows.map(\.dayKey), ["2026-09-19"])
    }

    func testDroppingAFutureDateAlsoRewritesTheFile() throws {
        try "date,marked_at\n2026-12-25,2026-01-01T00:00:00Z\n"
            .write(to: fileURL, atomically: true, encoding: .utf8)

        _ = MarkStore(fileURL: fileURL, todayKey: { "2026-09-20" })

        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "date,marked_at\n")
    }

    func testAFileWithNoFutureDatesIsLeftAlone() throws {
        let original = "date,marked_at\n2026-09-19,2026-09-19T00:00:00Z\n"
        try original.write(to: fileURL, atomically: true, encoding: .utf8)
        let before = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date

        _ = MarkStore(fileURL: fileURL, todayKey: { "2026-09-20" })

        let after = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date
        XCTAssertEqual(before, after)
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), original)
    }

    func testTheYearBoundaryIsComparedAsADateNotAsText() {
        let store = MarkStore(fileURL: fileURL, todayKey: { "2026-12-31" })

        store.toggle("2027-01-01")
        store.toggle("2026-01-01")

        XCTAssertFalse(store.isMarked("2027-01-01"))
        XCTAssertTrue(store.isMarked("2026-01-01"))
    }

    func testRowsComeOutSortedByDay() {
        let store = MarkStore(fileURL: fileURL)
        store.toggle("2026-09-13")
        store.toggle("2026-01-03")

        XCTAssertEqual(store.rows.map(\.dayKey), ["2026-01-03", "2026-09-13"])
    }

    /// A file the app cannot parse must not be silently overwritten by the next
    /// save; whatever it holds has to stay recoverable.
    func testAnUnreadableFileIsSetAsideRatherThanOverwritten() throws {
        try "this is not a csv\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let store = MarkStore(fileURL: fileURL)

        XCTAssertEqual(store.count, 0)
        XCTAssertNotNil(store.failure)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))

        let setAside = try FileManager.default
            .contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("roundel-unreadable-") }
        XCTAssertEqual(setAside.count, 1)

        let preserved = try String(
            contentsOf: directory.appendingPathComponent(try XCTUnwrap(setAside.first)),
            encoding: .utf8
        )
        XCTAssertEqual(preserved, "this is not a csv\n")
    }

    func testTheStoreStaysUsableAfterSettingAnUnreadableFileAside() throws {
        try "this is not a csv\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let store = MarkStore(fileURL: fileURL)

        store.toggle("2026-09-13")

        XCTAssertEqual(MarkStore(fileURL: fileURL).rows.map(\.dayKey), ["2026-09-13"])
    }
}
