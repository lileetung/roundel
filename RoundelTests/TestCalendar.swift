import Foundation

/// Weeks starting on Sunday and fixed to UTC, so the fixtures the grid and month
/// assertions depend on do not drift with the machine's regional settings.
///
/// Shared rather than declared per test file: `leadingBlanks`, `columnCount` and
/// the weekday rows are all functions of `firstWeekday`, so two copies would let
/// one file quietly test a different calendar than it claims.
enum TestCalendar {
    static let sundayFirstUTC: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        return calendar
    }()
}
