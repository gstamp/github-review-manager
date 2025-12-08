import SwiftUI

struct FilterButton: View {
    let filterType: PRFilterType
    let isActive: Bool
    let action: () -> Void

    @State private var isHovering = false
    @State private var showTooltip = false
    @State private var hoverTask: Task<Void, Never>?

    private let tooltipDelay: UInt64 = 300_000_000 // 300ms in nanoseconds

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
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                hoverTask = Task {
                    try? await Task.sleep(nanoseconds: tooltipDelay)
                    if !Task.isCancelled && isHovering {
                        showTooltip = true
                    }
                }
            } else {
                hoverTask?.cancel()
                hoverTask = nil
                showTooltip = false
            }
        }
        .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
            Text(filterType.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
        }
    }
}

