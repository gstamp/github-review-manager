import SwiftUI
import AppKit

struct SnoozeButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            SnoozeIcon()
        }
        .buttonStyle(PlainButtonStyle())
        .padding(6)
        .background(isHovered ? Color(NSColor.controlAccentColor).opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? Color(NSColor.controlAccentColor).opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .hoverCursor(.pointingHand)
        .help("Snooze PR")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

