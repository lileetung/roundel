import SwiftUI

struct DayCellView: View {
    let date: Date
    let calendar: Calendar
    let isMarked: Bool

    /// Answered by the store rather than reassembled here from its parts. A day
    /// that cannot be toggled has not arrived, and reads as unavailable.
    let isActionable: Bool

    let action: () -> Void

    @State private var isHovering = false

    private var isToday: Bool {
        calendar.isDateInToday(date)
    }

    private var dayNumber: Int {
        calendar.component(.day, from: date)
    }

    private var accessibilityDate: String {
        AppCalendar.spokenDate.string(from: date)
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)

                Circle()
                    .strokeBorder(borderColor, lineWidth: isMarked ? 2.5 : 1.25)

                Text("\(dayNumber)")
                    .font(.system(size: 13, weight: isMarked || isToday ? .semibold : .regular))
                    .foregroundStyle(isActionable ? Color.primary : Color.primary.opacity(0.3))
            }
            .frame(width: 30, height: 30)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isActionable)
        .onHover { isHovering = isActionable && $0 }
        .animation(.easeOut(duration: 0.12), value: isMarked)
        .animation(.easeOut(duration: 0.12), value: isHovering)
        .accessibilityLabel(Text(accessibilityDate))
        .accessibilityValue(Text(accessibilityStatus))
        .accessibilityHint(isActionable ? Text("toggle_hint") : Text(""))
    }

    private var backgroundColor: Color {
        if isMarked {
            return Color.red.opacity(isHovering ? 0.14 : 0.06)
        }
        return isHovering ? Color.primary.opacity(0.08) : Color.clear
    }

    private var accessibilityStatus: LocalizedStringKey {
        if isMarked { return "marked" }
        return isActionable ? "not_marked" : "not_yet_arrived"
    }

    private var borderColor: Color {
        if isMarked {
            return .red
        }
        return isToday ? Color.primary.opacity(0.4) : .clear
    }
}
