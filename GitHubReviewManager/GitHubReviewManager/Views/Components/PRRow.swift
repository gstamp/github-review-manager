import SwiftUI
import AppKit

struct PRRow<PR: PRRowItem>: View {
    let pr: PR
    let onCopy: () -> Void
    let onDismiss: () -> Void
    let onSnooze: (() -> Void)?
    let onApprove: (() -> Void)?
    let onMerge: (() -> Void)?
    let isMerging: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button(action: {
                    if let url = URL(string: pr.url) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text(pr.title)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                .buttonStyle(PlainButtonStyle())
                .hoverCursor(.pointingHand)

                Spacer()

                HStack(spacing: 4) {
                    // Show merge button for PRs that are approved, mergeable, not in merge queue, and don't have failed status
                    if pr.mergeQueueEntry == nil,
                       pr.reviewStatus == .approved,
                       pr.mergeable == true,
                       pr.statusState != .failure,
                       pr.statusState != .error,
                       let mergeAction = onMerge {
                        MergeButton(action: mergeAction, isLoading: isMerging)
                    }

                    // Show approve button for ReviewRequests that haven't been approved and don't have failing builds
                    if let reviewRequest = pr as? ReviewRequest,
                       reviewRequest.reviewStatus != .approved,
                       reviewRequest.statusState != .failure,
                       let approveAction = onApprove {
                        ApproveButton(action: approveAction)
                    }

                    CopyButton(action: onCopy)
                    if let snoozeAction = onSnooze {
                        SnoozeButton(action: snoozeAction)
                    }
                    Button(action: onDismiss) {
                        Text("×")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .hoverCursor(.pointingHand)
                    .help("Dismiss")
                }
            }

            HStack(spacing: 8) {
                Text("\(pr.repoOwner)/\(pr.repoName)#\(pr.number)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if let author = (pr as? ReviewRequest)?.author {
                    Text("by \(author)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                PRStatePill(state: pr.state)
                ReviewStatusPill(status: pr.reviewStatus)

                if let mergeQueueEntry = pr.mergeQueueEntry {
                    MergeQueuePill(entry: mergeQueueEntry)
                }

                if let statusState = pr.statusState {
                    StatusStatePill(state: statusState)
                }

                if let daysSinceReady = (pr as? PRSummary)?.daysSinceReady {
                    Text("Ready for \(String(format: "%.1f", daysSinceReady)) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let daysWaiting = (pr as? ReviewRequest)?.daysWaiting {
                    Text("Waiting \(String(format: "%.1f", daysWaiting)) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

protocol PRRowItem {
    var id: Int { get }
    var number: Int { get }
    var title: String { get }
    var url: String { get }
    var repoOwner: String { get }
    var repoName: String { get }
    var state: PRState { get }
    var reviewStatus: ReviewStatus { get }
    var statusState: StatusState? { get }
    var mergeable: Bool? { get }
    var mergeQueueEntry: MergeQueueEntryInfo? { get }
}

extension PRSummary: PRRowItem {}
extension ReviewRequest: PRRowItem {}

