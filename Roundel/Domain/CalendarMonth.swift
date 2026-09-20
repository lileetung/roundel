import Foundation

struct CalendarMonth: Equatable {
    let startDate: Date
    let calendar: Calendar

    init(containing date: Date, calendar: Calendar = AppCalendar.current) {
        self.calendar = calendar
        startDate = Self.startOfMonth(containing: date, calendar: calendar)
    }

    var title: String {
        let components = calendar.dateComponents([.year, .month], from: startDate)
        return String(format: "%04d/%02d", components.year ?? 0, components.month ?? 0)
    }

    var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstIndex = max(0, min(symbols.count - 1, calendar.firstWeekday - 1))
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    /// Leading and trailing nils keep every rendered row exactly seven cells wide.
    var cells: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: startDate) else {
            return []
        }

        let weekday = calendar.component(.weekday, from: startDate)
        let leadingEmptyCount = (weekday - calendar.firstWeekday + 7) % 7

        var result = Array<Date?>(repeating: nil, count: leadingEmptyCount)
        result.append(contentsOf: dayRange.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startDate)
        })

        let trailingEmptyCount = (7 - result.count % 7) % 7
        result.append(contentsOf: Array<Date?>(repeating: nil, count: trailingEmptyCount))
        return result
    }

    func moved(by numberOfMonths: Int) -> CalendarMonth {
        let date = calendar.date(byAdding: .month, value: numberOfMonths, to: startDate) ?? startDate
        return CalendarMonth(containing: date, calendar: calendar)
    }

    private static func startOfMonth(containing date: Date, calendar: Calendar) -> Date {
        var components = calendar.dateComponents([.era, .year, .month], from: date)
        components.day = 1
        // Noon avoids edge cases in regions whose daylight-saving transitions occur at midnight.
        components.hour = 12
        return calendar.date(from: components) ?? date
    }
}
