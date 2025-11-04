import SwiftUI
import AppKit

struct CopyButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            CopyIcon()
        }
        .buttonStyle(PlainButtonStyle())
        .padding(6)
        .background(isHovered ? Color(NSColor.controlAccentColor).opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? Color(NSColor.controlAccentColor).opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .hoverCursor(.pointingHand)
        .help("Copy Slack link")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

struct CopyAllButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            CopyIcon()
        }
        .buttonStyle(PlainButtonStyle())
        .padding(4)
        .background(Color.clear)
        .cornerRadius(4)
        .hoverCursor(.pointingHand)
        .help("Copy all PRs")
    }
}

