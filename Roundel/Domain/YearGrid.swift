import Foundation

/// Lays a calendar year out as a grid of weeks: one column per week, one row per
/// weekday.
///
/// January 1st rarely falls on the first day of the week, so the first column
/// starts part-way down. `leadingBlanks` is how many cells that leaves empty.
struct YearGrid: Equatable {
    let year: Int
    let calendar: Calendar
    let dayCount: Int
    let leadingBlanks: Int

    private let startOfYear: Date

    init?(year: Int, calendar: Calendar = AppCalendar.current) {
        var components = DateComponents()
        components.year = year
        components.month = 1
        components.day = 1
        // Noon keeps day arithmetic clear of daylight-saving transitions.
        components.hour = 12

        guard
            let start = calendar.date(from: components),
            let range = calendar.range(of: .day, in: .year, for: start)
        else {
            return nil
        }

        self.year = year
        self.calendar = calendar
        startOfYear = start
        dayCount = range.count
        leadingBlanks = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
    }

    var columnCount: Int {
        (leadingBlanks + dayCount + 6) / 7
    }

    /// `dayOfYear` is 1-based, matching `Calendar.ordinality`.
    func cell(forDayOfYear dayOfYear: Int) -> (column: Int, row: Int) {
        let offset = leadingBlanks + dayOfYear - 1
        return (column: offset / 7, row: offset % 7)
    }

    /// Returns nil for the blank cells before January 1st and after December 31st.
    func dayOfYear(atColumn column: Int, row: Int) -> Int? {
        guard row >= 0, row < 7 else { return nil }
        let dayOfYear = column * 7 + row - leadingBlanks + 1
        guard (1...dayCount).contains(dayOfYear) else { return nil }
        return dayOfYear
    }

    func date(dayOfYear: Int) -> Date? {
        guard (1...dayCount).contains(dayOfYear) else { return nil }
        return calendar.date(byAdding: .day, value: dayOfYear - 1, to: startOfYear)
    }

    func dayKey(dayOfYear: Int) -> String? {
        guard let date = date(dayOfYear: dayOfYear) else { return nil }
        return DayID(date: date, calendar: calendar).key
    }

    /// The reverse of `dayKey`, for turning a handful of stored marks into grid
    /// positions rather than asking all 366 days whether they are marked.
    /// Returns nil for keys outside this year or that are not a real date.
    func dayOfYear(forDayKey dayKey: String) -> Int? {
        let parts = dayKey.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3, parts[0] == year else { return nil }

        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        components.hour = 12

        guard let date = calendar.date(from: components) else { return nil }
        return calendar.ordinality(of: .day, in: .year, for: date)
    }

    /// The column each month opens in, for the tick labels above the grid.
    var monthColumns: [(month: Int, column: Int)] {
        (1...12).compactMap { month in
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = 1
            components.hour = 12

            guard
                let date = calendar.date(from: components),
                let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date)
            else {
                return nil
            }
            return (month: month, column: cell(forDayOfYear: dayOfYear).column)
        }
    }
}
