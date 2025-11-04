import SwiftUI
import AppKit

struct MergeButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            MergeIcon()
        }
        .buttonStyle(PlainButtonStyle())
        .padding(6)
        .background(isHovered ? Color.blue.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .hoverCursor(.pointingHand)
        .help("Merge PR")
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

