import SwiftUI
import AppKit

struct PRRow<PR: PRRowItem>: View {
    let pr: PR
    let onCopy: () -> Void
    let onDismiss: () -> Void
    let onApprove: (() -> Void)?

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
                    // Show approve button for ReviewRequests that haven't been approved and don't have failing builds
                    if let reviewRequest = pr as? ReviewRequest,
                       reviewRequest.reviewStatus != .approved,
                       reviewRequest.statusState != .failure,
                       let approveAction = onApprove {
                        Button(action: approveAction) {
                            ApproveIcon()
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(4)
                        .background(Color.clear)
                        .cornerRadius(4)
                        .hoverCursor(.pointingHand)
                        .help("Approve PR")
                    }

                    CopyButton(action: onCopy)
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
}

extension PRSummary: PRRowItem {}
extension ReviewRequest: PRRowItem {}

