import Foundation

/// Plain-text interchange for marked days.
///
/// The format is deliberately boring so that any spreadsheet can open it:
/// a header row, then one day per line.
///
///     date,marked_at
///     2026-09-13,2026-09-13T10:22:31Z
///
/// `marked_at` records when a day was first marked. It is optional on import;
/// rows that omit it are treated as marked at the moment of the import.
enum MarkedDayCSV {
    static let header = "date,marked_at"

    struct Row: Equatable {
        var dayKey: String
        var markedAt: Date
    }

    enum Failure: LocalizedError, Equatable {
        case emptyFile
        case malformedRow(line: Int)
        case invalidDate(line: Int, value: String)
        case invalidTimestamp(line: Int, value: String)

        var errorDescription: String? {
            switch self {
            case .emptyFile:
                return String(localized: "csv_error_empty")
            case let .malformedRow(line):
                return String(format: String(localized: "csv_error_malformed_row"), line)
            case let .invalidDate(line, value):
                return String(format: String(localized: "csv_error_invalid_date"), line, value)
            case let .invalidTimestamp(line, value):
                return String(format: String(localized: "csv_error_invalid_timestamp"), line, value)
            }
        }
    }

    static func encode(_ rows: [Row]) -> String {
        let body = rows
            .sorted { $0.dayKey < $1.dayKey }
            .map { "\($0.dayKey),\(timestampFormatter.string(from: $0.markedAt))" }
        return ([header] + body).joined(separator: "\n") + "\n"
    }

    /// Parses a CSV export. Rows are returned in file order with duplicate days
    /// collapsed to their first occurrence, so importing a file twice is a no-op.
    static func decode(_ text: String, importedAt: Date = .now) throws -> [Row] {
        // A byte-order mark is a prefix of the file, so it is stripped once. The
        // two-step newline pass is deliberate: collapsing it to a single CR rule
        // would double the line numbers reported in errors.
        let lines = text
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        var rows: [Row] = []
        var seen = Set<String>()
        var sawHeader = false

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let lineNumber = index + 1
            let fields = line
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }

            // Tolerate the header wherever a well-meaning spreadsheet leaves it.
            if fields[0].lowercased() == "date" {
                sawHeader = true
                continue
            }

            guard fields.count <= 2, !fields[0].isEmpty else {
                throw Failure.malformedRow(line: lineNumber)
            }
            let dayField = fields[0]

            guard let day = dayFormatter.date(from: dayField) else {
                throw Failure.invalidDate(line: lineNumber, value: dayField)
            }
            // Re-formatting normalises hand-typed dates such as 2026-9-3.
            let dayKey = dayFormatter.string(from: day)

            var markedAt = importedAt
            if fields.count == 2, !fields[1].isEmpty {
                guard let parsed = timestampFormatter.date(from: fields[1]) else {
                    throw Failure.invalidTimestamp(line: lineNumber, value: fields[1])
                }
                markedAt = parsed
            }

            if seen.insert(dayKey).inserted {
                rows.append(Row(dayKey: dayKey, markedAt: markedAt))
            }
        }

        // A header on its own is a legitimate export of nothing; a file with no
        // recognisable line at all is not.
        guard sawHeader || !rows.isEmpty else {
            throw Failure.emptyFile
        }

        return rows
    }

    /// Fixed to UTC and POSIX so a day label means the same thing on every Mac.
    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        return formatter
    }()

    private static let timestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}
