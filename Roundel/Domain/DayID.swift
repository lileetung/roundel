import Foundation

/// A calendar day without a time or time zone.
struct DayID: Hashable, Codable, Sendable {
    let year: Int
    let month: Int
    let day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year!, month: components.month!, day: components.day!)
    }

    var key: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

enum AppCalendar {
    /// Roundel presents in English everywhere, so the calendar is pinned to
    /// en_US: weekday and month names read the same on every Mac, and weeks
    /// start on Sunday regardless of the region the user has set.
    ///
    /// The time zone still follows the system, because which day counts as
    /// today has to match the user's actual clock.
    static let current: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }()

    /// Spelled out for VoiceOver.
    static let spokenDate = dateFormatter(style: .long)

    /// Short enough to sit in a single line of the dashboard.
    static let writtenDate = dateFormatter(style: .medium)

    /// `DateFormatter` is among the most expensive objects in Foundation, so the
    /// two the app needs are built once rather than per row or per redraw. The
    /// time zone stays autoupdating through the assignment, so marks do not shift
    /// when the system zone changes.
    private static func dateFormatter(style: DateFormatter.Style) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = current
        formatter.locale = current.locale
        formatter.timeZone = current.timeZone
        formatter.dateStyle = style
        return formatter
    }
}
