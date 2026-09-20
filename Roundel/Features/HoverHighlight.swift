import SwiftUI

/// The tint a day cell shows when hovered, reused by every icon button so the
/// whole app highlights the same way.
struct HoverHighlight: ViewModifier {
    @State private var isHovering = false

    func body(content: Content) -> some View {
        content
            .background {
                Circle()
                    .fill(isHovering ? Color.primary.opacity(0.08) : Color.clear)
            }
            .onHover { isHovering = $0 }
            .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

extension View {
    func hoverHighlight() -> some View {
        modifier(HoverHighlight())
    }
}
