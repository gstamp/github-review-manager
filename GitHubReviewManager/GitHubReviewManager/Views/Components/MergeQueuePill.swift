import SwiftUI

struct MergeQueuePill: View {
    let entry: MergeQueueEntryInfo

    var body: some View {
        let (text, color) = displayInfo
        StatusPill(text: text, color: color)
    }

    private var displayInfo: (String, Color) {
        switch entry.state {
        case .queued, .awaitingChecks:
            if let position = entry.position {
                return ("queued #\(position)", Color.cyan)
            }
            return ("queued", Color.cyan)
        case .locked:
            return ("merging", Color.purple)
        case .mergeable:
            return ("ready", Color.green)
        case .unmergeable:
            return ("queue failed", Color.red)
        }
    }
}

