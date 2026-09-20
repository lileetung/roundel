import AppKit
import SwiftUI

struct CalendarPopoverView: View {
    @Environment(MarkStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    @State private var visibleMonth = CalendarMonth(containing: .now)

    /// `cells` rebuilds the month on every read, and `CalendarMonth` pads it to a
    /// whole number of weeks, so one read and a plain stride is enough.
    private var rows: [[Date?]] {
        let cells = visibleMonth.cells
        return stride(from: 0, to: cells.count, by: 7).map { start in
            Array(cells[start..<(start + 7)])
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            monthHeader
            calendarGrid
        }
        .padding(14)
        .frame(width: 310)
        .alert("storage_error_title", isPresented: failureBinding) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(store.failure ?? "")
        }
    }

    /// The month navigation stays optically centred, so the dashboard button is
    /// laid over the trailing edge instead of joining the same row.
    private var monthHeader: some View {
        ZStack {
            monthNavigation

            HStack {
                TrackingEmojiButton()
                Spacer()
                dashboardButton
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var dashboardButton: some View {
        Button {
            // Hiding the panel directly leaves MenuBarExtra believing the
            // calendar is still on screen, so the next click on the menu bar item
            // spends itself clearing that stale state and the calendar only
            // reappears on the click after. Pressing the item programmatically
            // closes the calendar through the same path a click would take, which
            // keeps MenuBarExtra's own state in step.
            Self.menuBarItemButton?.performClick(nil)
            // One hop, to let the panel finish dismissing. Raising the window
            // no longer needs a second guess at the timing: the request stands
            // until the window is there to honour it.
            DispatchQueue.main.async {
                NSApp.activate()
                openWindow(id: DashboardView.windowID)
                DashboardView.bringToFront()
            }
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Circle())
                .hoverHighlight()
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: "Dashboard"))
    }

    private var monthNavigation: some View {
        HStack(spacing: 8) {
            Button {
                visibleMonth = visibleMonth.moved(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
                    .hoverHighlight()
            }
            .buttonStyle(.plain)
            .help(Text("previous_month"))

            // The title is always `%04d/%02d` and the digits are monospaced, so
            // its width never changes and needs no placeholder holding it open.
            Text(verbatim: visibleMonth.title)
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .accessibilityAddTraits(.isHeader)

            Button {
                visibleMonth = visibleMonth.moved(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
                    .hoverHighlight()
            }
            .buttonStyle(.plain)
            .help(Text("next_month"))
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var calendarGrid: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 5) {
            GridRow {
                ForEach(Array(visibleMonth.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 18)
                        .accessibilityHidden(true)
                }
            }

            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                GridRow {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, date in
                        if let date {
                            let dayID = DayID(date: date, calendar: visibleMonth.calendar)
                            DayCellView(
                                date: date,
                                calendar: visibleMonth.calendar,
                                isMarked: store.isMarked(dayID.key),
                                isActionable: store.canToggle(dayID.key)
                            ) {
                                store.toggle(dayID.key)
                            }
                        } else {
                            Color.clear
                                .frame(width: 30, height: 30)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
        }
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { store.failure != nil },
            set: { isPresented in
                if !isPresented { store.failure = nil }
            }
        )
    }
}

private extension CalendarPopoverView {
    /// The status item SwiftUI creates for the `MenuBarExtra`.
    ///
    /// The button sits a couple of levels inside the status bar window, so the
    /// search has to recurse; a direct scan of the content view's subviews finds
    /// nothing. Its action is SwiftUI's own `toggleWindow:`, which is why pressing
    /// it leaves MenuBarExtra's state consistent where hiding the panel does not.
    static var menuBarItemButton: NSStatusBarButton? {
        func firstButton(in view: NSView) -> NSStatusBarButton? {
            if let button = view as? NSStatusBarButton { return button }
            for subview in view.subviews {
                if let button = firstButton(in: subview) { return button }
            }
            return nil
        }

        return NSApp.windows.lazy.compactMap { $0.contentView.flatMap(firstButton) }.first
    }
}
