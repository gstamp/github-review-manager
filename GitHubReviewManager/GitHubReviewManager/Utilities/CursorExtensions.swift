import SwiftUI
import AppKit

extension View {
    /// Sets the cursor style for this view when hovering
    /// Uses NSCursor.set() directly instead of push/pop for better reliability
    func hoverCursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside {
                cursor.set()
            } else {
                NSCursor.arrow.set()
            }
        }
    }
}

