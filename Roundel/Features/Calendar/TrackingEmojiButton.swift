import SwiftUI

/// Lets the reader put a symbol on what they are recording.
///
/// The choice is a preference, not a record: it lives in `UserDefaults` and never
/// reaches `roundel.csv`, which stays a list of dates and nothing else.
struct TrackingEmojiButton: View {
    @AppStorage("trackingEmoji") private var trackingEmoji = ""

    @State private var isPickerPresented = false

    private struct Group: Identifiable {
        let id: String
        let emoji: [String]
    }

    /// Sport is listed in full, since a day marked for exercise is the case this
    /// app gets used for most; everything else is a smaller spread of the other
    /// things worth marking a day for.
    private static let groups = [
        Group(id: "Sport", emoji: [
            "⚽️", "🏀", "🏈", "⚾️", "🥎", "🎾", "🏐", "🏉",
            "🥏", "🎱", "🏓", "🏸", "🏒", "🏑", "🥍", "🏏",
            "⛳️", "🏹", "🎣", "🤿", "🏊", "🤽", "🚣", "🏄",
            "🥊", "🥋", "🤺", "🤼", "🤸", "🤾", "⛹️", "🏋️",
            "🧘", "💪", "🎽", "🏃", "🚶", "🧗", "🚴", "🚵",
            "⛷️", "🏂", "⛸️", "🥌", "🛹", "🛼", "🪂", "🏇",
            "🏌️", "🎯", "🪃", "🪁", "🏆", "🥇",
        ]),
        Group(id: "Other", emoji: [
            "📖", "✍️", "🎨", "🎸", "🎧", "💻",
            "🍎", "💧", "😴", "🚭", "🍺", "💊",
            "🧹", "💰", "🌱", "☀️", "🌙", "❤️",
            "⭐️", "✅", "🔥", "📷", "🐕", "🧠",
        ]),
    ]

    private let columns = Array(repeating: GridItem(.fixed(26), spacing: 2), count: 8)

    var body: some View {
        Button {
            isPickerPresented.toggle()
        } label: {
            label
                .frame(width: 24, height: 24)
                .contentShape(Circle())
                .hoverHighlight()
        }
        .buttonStyle(.plain)
        .help(Text(verbatim: "What you are tracking"))
        .accessibilityLabel(Text(verbatim: "What you are tracking"))
        .accessibilityValue(Text(verbatim: trackingEmoji.isEmpty ? "None" : trackingEmoji))
        .popover(isPresented: $isPickerPresented, arrowEdge: .bottom) {
            picker
        }
    }

    @ViewBuilder
    private var label: some View {
        if trackingEmoji.isEmpty {
            Image(systemName: "face.smiling")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        } else {
            Text(verbatim: trackingEmoji)
                .font(.system(size: 14))
        }
    }

    private var picker: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Self.groups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: group.id)
                                .font(.system(size: 10))
                                .foregroundStyle(.tertiary)

                            LazyVGrid(columns: columns, spacing: 2) {
                                ForEach(group.emoji, id: \.self, content: choice)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .frame(height: 250)

            Divider()

            Button {
                trackingEmoji = ""
                isPickerPresented = false
            } label: {
                Text(verbatim: "Clear")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(trackingEmoji.isEmpty)
        }
        .frame(width: 244)
    }

    private func choice(_ emoji: String) -> some View {
        Button {
            trackingEmoji = emoji
            isPickerPresented = false
        } label: {
            Text(verbatim: emoji)
                .font(.system(size: 15))
                .frame(width: 26, height: 26)
                .background {
                    Circle()
                        .fill(emoji == trackingEmoji ? Color.red.opacity(0.18) : Color.clear)
                }
                .overlay {
                    Circle()
                        .strokeBorder(emoji == trackingEmoji ? Color.red : .clear, lineWidth: 1.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: emoji))
    }
}
