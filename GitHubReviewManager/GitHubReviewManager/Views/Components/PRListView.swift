import SwiftUI
import AppKit

struct PRListView<PR: PRRowItem & Identifiable>: View {
    let prs: [PR]
    let emptyMessage: String
    let onCopy: (PR) -> Void
    let onDismiss: (PR) -> Void
    let onSnooze: ((PR) -> Void)?
    let onApprove: ((PR) -> Void)?
    let onMerge: ((PR) -> Void)?
    let showCopyAll: Bool
    let onCopyAll: (() -> Void)?
    let snoozedCount: Int
    let dismissedCount: Int
    let mergingPRIds: Set<Int>
    @Binding var filterState: PRFilterState
    let onFilterChanged: () -> Void
    let showDraftsToggle: Bool
    let onUnsnooze: ((PR) -> Void)?
    let onUndismiss: ((PR) -> Void)?

    init(
        prs: [PR],
        emptyMessage: String = "No PRs found",
        onCopy: @escaping (PR) -> Void,
        onDismiss: @escaping (PR) -> Void,
        onSnooze: ((PR) -> Void)? = nil,
        onApprove: ((PR) -> Void)? = nil,
        onMerge: ((PR) -> Void)? = nil,
        showCopyAll: Bool = false,
        onCopyAll: (() -> Void)? = nil,
        snoozedCount: Int = 0,
        dismissedCount: Int = 0,
        mergingPRIds: Set<Int> = [],
        filterState: Binding<PRFilterState>,
        onFilterChanged: @escaping () -> Void,
        showDraftsToggle: Bool = false,
        onUnsnooze: ((PR) -> Void)? = nil,
        onUndismiss: ((PR) -> Void)? = nil
    ) {
        self.prs = prs
        self.emptyMessage = emptyMessage
        self.onCopy = onCopy
        self.onDismiss = onDismiss
        self.onSnooze = onSnooze
        self.onApprove = onApprove
        self.onMerge = onMerge
        self.showCopyAll = showCopyAll
        self.onCopyAll = onCopyAll
        self.snoozedCount = snoozedCount
        self.dismissedCount = dismissedCount
        self.mergingPRIds = mergingPRIds
        self._filterState = filterState
        self.onFilterChanged = onFilterChanged
        self.showDraftsToggle = showDraftsToggle
        self.onUnsnooze = onUnsnooze
        self.onUndismiss = onUndismiss
    }

    private var filteredPRs: [PR] {
        filterState.filter(prs)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header row with filters and copy all
                HStack {
                    FilterBar(
                        filterState: $filterState,
                        onFilterChanged: onFilterChanged,
                        showDraftsToggle: showDraftsToggle,
                        snoozedCount: snoozedCount,
                        dismissedCount: dismissedCount
                    )

                    Spacer()

                    if showCopyAll, let copyAll = onCopyAll {
                        CopyAllButton {
                            copyAll()
                        }
                    }
                }
                .padding(.horizontal)

                if filteredPRs.isEmpty {
                    if prs.isEmpty {
                        Text(emptyMessage)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        Text("No PRs match the selected filters")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                } else {
                    ForEach(filteredPRs) { pr in
                        PRRow(
                            pr: pr,
                            onCopy: {
                                onCopy(pr)
                            },
                            onDismiss: {
                                onDismiss(pr)
                            },
                            onSnooze: onSnooze.map { snooze in
                                {
                                    snooze(pr)
                                }
                            },
                            onApprove: onApprove.map { approve in
                                {
                                    approve(pr)
                                }
                            },
                            onMerge: onMerge.map { merge in
                                {
                                    merge(pr)
                                }
                            },
                            isMerging: mergingPRIds.contains(pr.id),
                            onUnsnooze: onUnsnooze.map { unsnooze in
                                {
                                    unsnooze(pr)
                                }
                            },
                            onUndismiss: onUndismiss.map { undismiss in
                                {
                                    undismiss(pr)
                                }
                            }
                        )
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }
}
