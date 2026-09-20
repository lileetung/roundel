import AppKit
import SwiftUI

/// A year of days as a grid of dots: one column per week, one row per weekday.
///
/// Roundel marks days with a ring, so the year reads in circles rather than the
/// squares the contribution-graph convention would suggest.
struct YearDotGridView: View {
    let grid: YearGrid
    let markedKeys: Set<String>

    /// The store's today, so the grid judges the future by the same clock the
    /// rule is written and tested against.
    let todayKey: String

    @Binding var hoveredDayOfYear: Int?
    let onToggle: (Int) -> Void

    @Environment(\.colorScheme) private var colorScheme

    /// Sized so a cell is a comfortable click target, not just a legible dot: a
    /// mis-click marks the wrong day, and one extra red dot among three hundred
    /// is easy to miss.
    private static let dotDiameter: CGFloat = 8
    private static let pitch: CGFloat = 12

    /// The hover and today rings are drawn outside the dot, so the canvas carries
    /// a margin wide enough for them. Without it the outermost rings are clipped.
    private static let ringMargin: CGFloat = 3

    /// A leap year whose first day falls on the last weekday of a column needs 54
    /// of them: 6 leading blanks plus 366 days. Reserving the maximum keeps the
    /// window from resizing as the reader steps between years.
    static let columnCapacity = 54

    static let width = CGFloat(columnCapacity) * pitch - (pitch - dotDiameter) + ringMargin * 2
    private static let height = 7 * pitch - (pitch - dotDiameter) + ringMargin * 2

    // MARK: - Day lookups
    //
    // Resolved once per render from the marks themselves — a dozen or so — rather
    // than asking each of 366 dots to build a date and format a key.

    private var markedDays: Set<Int> {
        Set(markedKeys.compactMap(grid.dayOfYear(forDayKey:)))
    }

    private var todayDay: Int? {
        grid.dayOfYear(forDayKey: todayKey)
    }

    /// The last day of this year that has arrived: every day, none of them, or up
    /// to today when the year on screen is the current one.
    private var markableThrough: Int {
        if let todayDay { return todayDay }
        return todayKey > "\(grid.year)-12-31" ? grid.dayCount : 0
    }

    var body: some View {
        let markedDays = markedDays
        let todayDay = todayDay
        let markableThrough = markableThrough

        return VStack(alignment: .leading, spacing: 6) {
            monthTicks
            dots(markedDays: markedDays, todayDay: todayDay, markableThrough: markableThrough)
                .accessibilityElement()
                .accessibilityLabel(Text(summary(markedCount: markedDays.count)))
        }
        .frame(width: Self.width, alignment: .leading)
    }

    private var monthTicks: some View {
        let symbols = grid.calendar.shortStandaloneMonthSymbols

        return ZStack(alignment: .topLeading) {
            ForEach(grid.monthColumns, id: \.month) { tick in
                Text(symbols[tick.month - 1])
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .offset(x: Self.ringMargin + CGFloat(tick.column) * Self.pitch)
            }
        }
        .frame(width: Self.width, height: 11, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func dots(markedDays: Set<Int>, todayDay: Int?, markableThrough: Int) -> some View {
        Canvas { context, _ in
            for dayOfYear in 1...grid.dayCount {
                let cell = grid.cell(forDayOfYear: dayOfYear)
                let rect = CGRect(
                    x: Self.ringMargin + CGFloat(cell.column) * Self.pitch,
                    y: Self.ringMargin + CGFloat(cell.row) * Self.pitch,
                    width: Self.dotDiameter,
                    height: Self.dotDiameter
                )
                let isMarked = markedDays.contains(dayOfYear)

                context.fill(Path(ellipseIn: rect), with: .color(isMarked ? .red : emptyDotColor))

                if dayOfYear == todayDay && !isMarked {
                    context.stroke(
                        Path(ellipseIn: rect.insetBy(dx: -1.5, dy: -1.5)),
                        with: .color(todayRingColor),
                        lineWidth: 1
                    )
                }

                if dayOfYear == hoveredDayOfYear {
                    context.stroke(
                        Path(ellipseIn: rect.insetBy(dx: -2.5, dy: -2.5)),
                        with: .color(hoverRingColor),
                        lineWidth: 1
                    )
                }
            }
        }
        .frame(width: Self.width, height: Self.height)
        .onContinuousHover { phase in
            guard case let .active(point) = phase else {
                hoveredDayOfYear = nil
                NSCursor.arrow.set()
                return
            }

            let day = day(at: point)
            // Only on a change: every write re-runs the dashboard's body and
            // redraws all 366 dots, and the pointer reports far more often than
            // it crosses a cell.
            if day != hoveredDayOfYear {
                hoveredDayOfYear = day
            }

            // Outside the guard: AppKit restores the arrow from the window's
            // cursor rects as the pointer travels, so this has to be reasserted.
            let isActionable = day.map { markedDays.contains($0) || $0 <= markableThrough } ?? false
            (isActionable ? NSCursor.pointingHand : NSCursor.arrow).set()
        }
        // The store refuses days that have not arrived, so there is nothing for a
        // second copy of that rule to add here.
        .onTapGesture {
            hoveredDayOfYear.map(onToggle)
        }
    }

    private func day(at point: CGPoint) -> Int? {
        let x = point.x - Self.ringMargin
        let y = point.y - Self.ringMargin
        guard x >= 0, y >= 0 else { return nil }
        return grid.dayOfYear(atColumn: Int(x / Self.pitch), row: Int(y / Self.pitch))
    }

    /// Resolved against the colour scheme rather than left to `Color.primary`,
    /// which a `Canvas` does not always reinterpret when the scheme changes.
    private var emptyDotColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.08)
    }

    private var todayRingColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.30)
    }

    private var hoverRingColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.45)
    }

    private func summary(markedCount: Int) -> String {
        String(format: String(localized: "year_grid_summary"), grid.year, markedCount)
    }
}
