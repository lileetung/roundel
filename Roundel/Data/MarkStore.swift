import Foundation
import Observation

/// Everything Roundel knows: which days are marked, and when each was marked.
///
/// The marks live in the same CSV the user can export, so the app has one format
/// rather than a database alongside an interchange file. Thirty years of daily
/// marks comes to a third of a megabyte, which is small enough to read once at
/// launch and rewrite whole on every change.
@MainActor
@Observable
final class MarkStore {
    private(set) var marks: [String: Date] = [:]

    /// Set when the file could not be read or written. `CalendarPopoverView`
    /// surfaces it; the store keeps working on whatever it has in memory.
    var failure: String?

    let fileURL: URL

    /// Injected so the future-date rule can be tested without waiting for the
    /// calendar to turn over.
    private let todayKey: () -> String

    init(
        fileURL: URL,
        todayKey: @escaping () -> String = { DayID(date: .now, calendar: AppCalendar.current).key }
    ) {
        self.fileURL = fileURL
        self.todayKey = todayKey
        load()
    }

    // MARK: - Reading the marks

    var count: Int { marks.count }

    var dayKeys: Set<String> { Set(marks.keys) }

    func isMarked(_ dayKey: String) -> Bool { marks[dayKey] != nil }

    var rows: [MarkedDayCSV.Row] {
        marks
            .map { MarkedDayCSV.Row(dayKey: $0.key, markedAt: $0.value) }
            .sorted { $0.dayKey < $1.dayKey }
    }

    // MARK: - Changing the marks

    /// Day keys are zero-padded `YYYY-MM-DD`, so comparing them as strings orders
    /// them as dates.
    /// The store's own idea of today, so the views judge the future by the same
    /// clock the rule is tested against rather than reading `.now` themselves.
    var today: String { todayKey() }

    func isInFuture(_ dayKey: String) -> Bool {
        dayKey > today
    }

    /// The whole question the views need to ask, rather than the halves they
    /// would otherwise recombine themselves. Getting that recombination wrong is
    /// what once stranded already-marked future days with no way to clear them.
    func canToggle(_ dayKey: String) -> Bool {
        isMarked(dayKey) || !isInFuture(dayKey)
    }

    /// A mark records something that happened, so a day that has not arrived
    /// cannot be marked. Removing is always allowed: a future mark can still
    /// arrive through an import, and it would otherwise be impossible to undo.
    func toggle(_ dayKey: String) {
        if marks.removeValue(forKey: dayKey) != nil {
            save()
            return
        }

        guard !isInFuture(dayKey) else { return }

        marks[dayKey] = .now
        save()
    }

    /// Adds days that are not marked yet and leaves existing marks untouched, so
    /// importing the same file twice changes nothing.
    ///
    /// Days that have not arrived are dropped rather than imported, the same rule
    /// `load` applies: Roundel holds no future dates, whatever their source.
    @discardableResult
    func merge(_ rows: [MarkedDayCSV.Row]) -> (added: Int, alreadyMarked: Int, inFuture: Int) {
        var added = 0
        var inFuture = 0
        let today = todayKey()

        for row in rows {
            guard row.dayKey <= today else {
                inFuture += 1
                continue
            }
            guard marks[row.dayKey] == nil else { continue }

            marks[row.dayKey] = row.markedAt
            added += 1
        }

        if added > 0 {
            save()
        }
        return (added: added, alreadyMarked: rows.count - added - inFuture, inFuture: inFuture)
    }

    // MARK: - The file

    /// Called once, from `init`; the store has no reason to reload while running.
    private func load() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }

        do {
            let text = try String(contentsOf: fileURL, encoding: .utf8)
            let rows = try MarkedDayCSV.decode(text)
            let today = todayKey()
            let usable = rows.filter { $0.dayKey <= today }

            marks = Dictionary(uniqueKeysWithValues: usable.map { ($0.dayKey, $0.markedAt) })

            // Marks made before the rule existed, or added by hand, are dropped
            // from the file as well, so what is on disk matches what is shown.
            if usable.count != rows.count {
                save()
            }
        } catch {
            // Move the unreadable file aside rather than letting the next save
            // overwrite it. Whatever it holds stays recoverable by hand.
            let quarantined = quarantineUnreadableFile()
            failure = String(
                format: String(localized: "load_error_message"),
                error.localizedDescription,
                quarantined?.lastPathComponent ?? fileURL.lastPathComponent
            )
        }
    }

    private func save() {
        do {
            try MarkedDayCSV.encode(rows).write(to: fileURL, atomically: true, encoding: .utf8)
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }

    private func quarantineUnreadableFile() -> URL? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"

        // Derived from the file's own name so the two cannot drift apart.
        let stem = fileURL.deletingPathExtension().lastPathComponent
        let target = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(stem)-unreadable-\(formatter.string(from: .now)).csv")

        guard (try? FileManager.default.moveItem(at: fileURL, to: target)) != nil else {
            return nil
        }
        return target
    }
}
