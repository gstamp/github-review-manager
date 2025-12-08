import SwiftUI

struct FilterButton: View {
    let filterType: PRFilterType
    let isActive: Bool
    let action: () -> Void

    private var iconName: String {
        switch filterType {
        case .failed:
            return isActive ? "xmark.circle.fill" : "xmark.circle"
        case .passed:
            return isActive ? "checkmark.diamond.fill" : "checkmark.diamond"
        case .approved:
            return isActive ? "checkmark.circle.fill" : "checkmark.circle"
        case .unapproved:
            return isActive ? "clock.fill" : "clock"
        case .mergeable:
            return isActive ? "arrow.triangle.merge" : "arrow.triangle.merge"
        }
    }

    private var iconColor: Color {
        guard isActive else {
            return .secondary
        }

        switch filterType {
        case .failed:
            return .red
        case .passed:
            return .green
        case .approved:
            return .mint
        case .unapproved:
            return .orange
        case .mergeable:
            return .blue
        }
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: iconName)
                .font(.system(size: 12))
                .foregroundColor(iconColor)
                .frame(width: 20, height: 20)
                .background(
                    isActive
                        ? iconColor.opacity(0.15)
                        : Color.clear
                )
                .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
        .hoverCursor(.pointingHand)
        .help(filterType.displayName)
    }
}

