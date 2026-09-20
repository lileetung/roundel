import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DashboardView: View {
    static let windowID = "dashboard"
    static let windowTitle = "Roundel Dashboard"

    /// `openWindow` creates the window but leaves an accessory app's window
    /// behind whatever the user was looking at, so it is raised explicitly.
    /// `orderFrontRegardless` is what actually lifts it above other apps, since
    /// an accessory app is not guaranteed to win activation.
    ///
    /// SwiftUI decides when the window comes into being, so a caller that has
    /// just asked for it may find nothing yet. Rather than poll, the request is
    /// remembered and the window honours it as it appears.
    static func bringToFront() {
        guard let hostWindow else {
            wantsFront = true
            return
        }
        raise(hostWindow)
    }

    private static weak var hostWindow: NSWindow?
    private static var wantsFront = false

    private static func register(_ window: NSWindow) {
        hostWindow = window
        guard wantsFront else { return }
        wantsFront = false
        raise(window)
    }

    private static func raise(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    @Environment(MarkStore.self) private var store

    @State private var selectedYear = AppCalendar.current.component(.year, from: .now)
    @State private var hoveredDayOfYear: Int?
    @State private var alert: AlertContent?

    private let calendar = AppCalendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            yearGrid
            readout
            Divider()
                .padding(.horizontal, 20)
            actions
        }
        .padding(20)
        .frame(width: YearDotGridView.width + 40, alignment: .leading)
        .background(HostWindowReader(onResolve: Self.register))
        .alert(alert?.title ?? "", isPresented: alertBinding) {
            Button("ok", role: .cancel) {}
        } message: {
            Text(alert?.message ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            yearStepper(by: -1, symbol: "chevron.left", help: "previous_year")

            Text(verbatim: String(selectedYear))
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .accessibilityAddTraits(.isHeader)

            yearStepper(by: 1, symbol: "chevron.right", help: "next_year")

            Spacer()

            HStack(spacing: 6) {
                Text(verbatim: "Total marked")
                    .foregroundStyle(.secondary)
                Text(verbatim: "\(store.count)")
                    .monospacedDigit()
            }
            .font(.system(size: 12))
            .accessibilityElement(children: .combine)
        }
    }

    private func yearStepper(by offset: Int, symbol: String, help: LocalizedStringKey) -> some View {
        Button {
            selectedYear += offset
            hoveredDayOfYear = nil
        } label: {
            Image(systemName: symbol)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!selectableYears.contains(selectedYear + offset))
        .help(Text(help))
    }

    // MARK: - Grid

    private var grid: YearGrid? {
        YearGrid(year: selectedYear, calendar: calendar)
    }

    @ViewBuilder
    private var yearGrid: some View {
        if let grid {
            YearDotGridView(
                grid: grid,
                markedKeys: store.dayKeys,
                todayKey: store.today,
                hoveredDayOfYear: $hoveredDayOfYear
            ) { dayOfYear in
                if let dayKey = grid.dayKey(dayOfYear: dayOfYear) {
                    store.toggle(dayKey)
                }
            }
        }
    }

    /// Names whichever day the pointer is over. The dot's own colour already says
    /// whether it is marked, so only the date is worth spelling out. Fixed height,
    /// so the window does not shift as the reader moves across the grid.
    private var readout: some View {
        HStack(spacing: 28) {
            if let hovered = hoveredDayOfYear, let date = hoveredDate(hovered) {
                Text(verbatim: mediumDate(date))
                    .monospacedDigit()
            } else if store.count == 0 {
                Text("empty_hint")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.system(size: 12))
        .frame(height: 16, alignment: .leading)
    }

    // MARK: - Actions

    private var actions: some View {
        HStack(spacing: 8) {
            Button { exportCSV() } label: { Text(verbatim: "Export CSV") }
                .disabled(store.count == 0)
            Button { importCSV() } label: { Text(verbatim: "Import CSV") }

            Spacer()

            Button { NSApp.terminate(nil) } label: {
                Image(systemName: "power")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .contentShape(Circle())
                    .hoverHighlight()
            }
            .buttonStyle(.plain)
            .help(Text(verbatim: "Quit Roundel"))
            .accessibilityLabel(Text(verbatim: "Quit Roundel"))
        }
    }

    // MARK: - Derived values

    /// Navigation is bounded by the data: there is nothing to look at in a year
    /// that sits outside the marks and the present.
    private var selectableYears: ClosedRange<Int> {
        let currentYear = calendar.component(.year, from: .now)
        let markedYears = store.marks.keys.lazy.compactMap { Int($0.prefix(4)) }
        let lower = min(markedYears.min() ?? currentYear, currentYear)
        let upper = max(markedYears.max() ?? currentYear, currentYear)
        return lower...upper
    }

    private func hoveredDate(_ dayOfYear: Int) -> Date? {
        grid?.date(dayOfYear: dayOfYear)
    }

    private func mediumDate(_ date: Date) -> String {
        AppCalendar.writtenDate.string(from: date)
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alert != nil },
            set: { isPresented in
                if !isPresented { alert = nil }
            }
        )
    }

    // MARK: - Import and export

    private func exportCSV() {
        NSApp.activate()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = defaultExportFilename
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try MarkedDayCSV.encode(store.rows).write(to: url, atomically: true, encoding: .utf8)
        } catch {
            alert = AlertContent(title: "export_error_title", message: error.localizedDescription)
        }
    }

    private func importCSV() {
        NSApp.activate()

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let text = try String(contentsOf: url, encoding: .utf8)
            let result = store.merge(try MarkedDayCSV.decode(text))

            // Dropped rows are named rather than folded into one number, so a
            // file that loses days to the future rule does not look like a bug.
            let message = result.inFuture == 0
                ? String(
                    format: String(localized: "import_result_message"),
                    result.added,
                    result.alreadyMarked
                )
                : String(
                    format: String(localized: "import_result_message_with_future"),
                    result.added,
                    result.alreadyMarked,
                    result.inFuture
                )

            alert = AlertContent(title: "import_result_title", message: message)
        } catch {
            alert = AlertContent(title: "import_error_title", message: error.localizedDescription)
        }
    }

    private var defaultExportFilename: String {
        "roundel-\(store.today).csv"
    }

    private struct AlertContent {
        let title: LocalizedStringKey
        let message: String
    }
}

/// Hands the window hosting the dashboard back to it. SwiftUI offers no way to
/// reach the window behind a `Window` scene, and pushing it out as it appears
/// beats polling `NSApp.windows` for a matching title.
private struct HostWindowReader: NSViewRepresentable {
    let onResolve: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        // The view is not in a window yet while it is being made.
        DispatchQueue.main.async { view.window.map(onResolve) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window.map(onResolve)
    }
}
