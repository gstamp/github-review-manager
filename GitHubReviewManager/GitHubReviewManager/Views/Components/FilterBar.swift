import SwiftUI

struct FilterBar: View {
    @Binding var filterState: PRFilterState
    let onFilterChanged: () -> Void

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

            if !filterState.isEmpty {
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

