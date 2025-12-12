import SwiftUI

struct FilterButton: View {
    let filterType: PRFilterType
    let isActive: Bool
    let action: () -> Void

    private var buttonColor: Color {
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
            Text(filterType.displayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isActive ? buttonColor.opacity(0.2) : Color.clear)
                .foregroundColor(isActive ? buttonColor : .secondary)
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isActive ? buttonColor.opacity(0.5) : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .hoverCursor(.pointingHand)
    }
}

