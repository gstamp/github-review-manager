import SwiftUI
import AppKit

struct CopyButton: View {
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
        .help("Copy Slack link")
        .onHover { hovering in
            // Optional: add hover effect
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

