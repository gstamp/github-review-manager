import SwiftUI
import AppKit

struct MergeButton: View {
    let action: () -> Void
    let isLoading: Bool
    @State private var isHovered = false

    init(action: @escaping () -> Void, isLoading: Bool = false) {
        self.action = action
        self.isLoading = isLoading
    }

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 16, height: 16)
            } else {
                MergeIcon()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .padding(6)
        .background(isHovered && !isLoading ? Color.blue.opacity(0.15) : Color.clear)
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered && !isLoading ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
        .hoverCursor(isLoading ? .arrow : .pointingHand)
        .help(isLoading ? "Merging..." : "Merge PR")
        .onHover { hovering in
            if !isLoading {
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
        }
    }
}

