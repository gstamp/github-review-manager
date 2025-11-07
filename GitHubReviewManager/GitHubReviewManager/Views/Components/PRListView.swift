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
    let onShowSnoozed: (() -> Void)?
    let onShowDismissed: (() -> Void)?

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
        onShowSnoozed: (() -> Void)? = nil,
        onShowDismissed: (() -> Void)? = nil
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
        self.onShowSnoozed = onShowSnoozed
        self.onShowDismissed = onShowDismissed
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if prs.isEmpty {
                        Text(emptyMessage)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        if showCopyAll, let copyAll = onCopyAll {
                            HStack {
                                Spacer()
                                CopyAllButton {
                                    copyAll()
                                }
                            }
                            .padding(.horizontal)
                        }

                        ForEach(prs) { pr in
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
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }

            // Bottom label for snoozed/dismissed counts
            if snoozedCount > 0 || dismissedCount > 0 {
                Divider()
                HStack {
                    Spacer()
                    HStack(spacing: 12) {
                        if snoozedCount > 0, let onShowSnoozed = onShowSnoozed {
                            Button(action: onShowSnoozed) {
                                Text("\(snoozedCount) snoozed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .hoverCursor(.pointingHand)
                        }

                        if dismissedCount > 0, let onShowDismissed = onShowDismissed {
                            Button(action: onShowDismissed) {
                                Text("\(dismissedCount) dismissed")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .hoverCursor(.pointingHand)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .background(Color(NSColor.windowBackgroundColor))
            }
        }
    }
}

