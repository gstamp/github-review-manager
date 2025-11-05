import SwiftUI

struct PRListView<PR: PRRowItem & Identifiable>: View {
    let prs: [PR]
    let emptyMessage: String
    let onCopy: (PR) -> Void
    let onDismiss: (PR) -> Void
    let onApprove: ((PR) -> Void)?
    let onMerge: ((PR) -> Void)?
    let showCopyAll: Bool
    let onCopyAll: (() -> Void)?

    init(
        prs: [PR],
        emptyMessage: String = "No PRs found",
        onCopy: @escaping (PR) -> Void,
        onDismiss: @escaping (PR) -> Void,
        onApprove: ((PR) -> Void)? = nil,
        onMerge: ((PR) -> Void)? = nil,
        showCopyAll: Bool = false,
        onCopyAll: (() -> Void)? = nil
    ) {
        self.prs = prs
        self.emptyMessage = emptyMessage
        self.onCopy = onCopy
        self.onDismiss = onDismiss
        self.onApprove = onApprove
        self.onMerge = onMerge
        self.showCopyAll = showCopyAll
        self.onCopyAll = onCopyAll
    }

    var body: some View {
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
    }
}

