import SwiftUI
import AppKit

enum SnoozeDuration: TimeInterval, Hashable {
    case oneDay = 86400
    case threeDays = 259200
    case oneWeek = 604800
    case oneMonth = 2592000

    var displayName: String {
        switch self {
        case .oneDay:
            return "1 Day"
        case .threeDays:
            return "3 Days"
        case .oneWeek:
            return "1 Week"
        case .oneMonth:
            return "1 Month"
        }
    }

    var expirationDate: Date {
        Date().addingTimeInterval(self.rawValue)
    }
}

struct SnoozePicker: View {
    let onSelect: (SnoozeDuration) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Snooze for how long?")
                .font(.headline)
                .padding(.top, 20)

            VStack(spacing: 10) {
                ForEach([SnoozeDuration.oneDay, .threeDays, .oneWeek, .oneMonth], id: \.self) { duration in
                    Button(action: {
                        onSelect(duration)
                    }) {
                        Text(duration.displayName)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)

            Button("Cancel", role: .cancel) {
                onCancel()
            }
            .padding(.bottom, 20)
        }
        .frame(width: 280, height: 300)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
}

