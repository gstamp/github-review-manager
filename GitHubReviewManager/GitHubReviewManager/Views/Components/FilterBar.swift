import SwiftUI

struct FilterBar: View {
    @Binding var filterState: PRFilterState
    let onFilterChanged: () -> Void
    var showDraftsToggle: Bool = false
    var snoozedCount: Int = 0
    var dismissedCount: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PRFilterType.allCases, id: \.self) { filterType in
                FilterButton(
                    filterType: filterType,
                    isActive: filterState.isActive(filterType),
                    action: {
                        filterState.toggle(filterType)
                        onFilterChanged()
                    }
                )
            }

            if showDraftsToggle {
                Button(action: {
                    filterState.showDrafts.toggle()
                    onFilterChanged()
                }) {
                    Text("Drafts")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(filterState.showDrafts ? Color.purple.opacity(0.2) : Color.clear)
                        .foregroundColor(filterState.showDrafts ? .purple : .secondary)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(filterState.showDrafts ? Color.purple.opacity(0.5) : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .hoverCursor(.pointingHand)
            }

            if snoozedCount > 0 {
                Button(action: {
                    filterState.showSnoozed.toggle()
                    onFilterChanged()
                }) {
                    Text("Snoozed (\(snoozedCount))")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(filterState.showSnoozed ? Color.orange.opacity(0.2) : Color.clear)
                        .foregroundColor(filterState.showSnoozed ? .orange : .secondary)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(filterState.showSnoozed ? Color.orange.opacity(0.5) : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .hoverCursor(.pointingHand)
            }

            if dismissedCount > 0 {
                Button(action: {
                    filterState.showDismissed.toggle()
                    onFilterChanged()
                }) {
                    Text("Dismissed (\(dismissedCount))")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(filterState.showDismissed ? Color.gray.opacity(0.2) : Color.clear)
                        .foregroundColor(filterState.showDismissed ? .primary : .secondary)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(filterState.showDismissed ? Color.gray.opacity(0.5) : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .hoverCursor(.pointingHand)
            }

            if !filterState.activeFilters.isEmpty || filterState.showDrafts || filterState.showSnoozed || filterState.showDismissed {
                Button(action: {
                    filterState = PRFilterState()
                    onFilterChanged()
                }) {
                    Text("Clear")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .hoverCursor(.pointingHand)
            }
        }
    }
}

