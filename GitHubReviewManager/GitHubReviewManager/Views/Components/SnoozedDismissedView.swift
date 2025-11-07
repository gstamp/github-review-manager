import SwiftUI
import AppKit

struct SnoozedDismissedView: View {
    let snoozedPRs: [PRSummary]
    let snoozedRequests: [ReviewRequest]
    let dismissedPRs: [PRSummary]
    let dismissedRequests: [ReviewRequest]
    let onUnsnooze: (Int) -> Void
    let onUndismiss: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Snoozed & Dismissed PRs")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("Close") {
                    dismiss()
                }
            }
            .padding()

            Divider()

            // Content
            TabView {
                // Snoozed Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if snoozedPRs.isEmpty && snoozedRequests.isEmpty {
                            Text("No snoozed PRs")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(snoozedPRs) { pr in
                                SnoozedDismissedRow(
                                    title: pr.title,
                                    repo: "\(pr.repoOwner)/\(pr.repoName)#\(pr.number)",
                                    url: pr.url,
                                    onRestore: {
                                        onUnsnooze(pr.id)
                                    }
                                )
                            }
                            ForEach(snoozedRequests) { request in
                                SnoozedDismissedRow(
                                    title: request.title,
                                    repo: "\(request.repoOwner)/\(request.repoName)#\(request.number)",
                                    url: request.url,
                                    onRestore: {
                                        onUnsnooze(request.id)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
                .tabItem {
                    Text("Snoozed (\(snoozedPRs.count + snoozedRequests.count))")
                }

                // Dismissed Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if dismissedPRs.isEmpty && dismissedRequests.isEmpty {
                            Text("No dismissed PRs")
                                .foregroundColor(.secondary)
                                .padding()
                        } else {
                            ForEach(dismissedPRs) { pr in
                                SnoozedDismissedRow(
                                    title: pr.title,
                                    repo: "\(pr.repoOwner)/\(pr.repoName)#\(pr.number)",
                                    url: pr.url,
                                    onRestore: {
                                        onUndismiss(pr.id)
                                    }
                                )
                            }
                            ForEach(dismissedRequests) { request in
                                SnoozedDismissedRow(
                                    title: request.title,
                                    repo: "\(request.repoOwner)/\(request.repoName)#\(request.number)",
                                    url: request.url,
                                    onRestore: {
                                        onUndismiss(request.id)
                                    }
                                )
                            }
                        }
                    }
                    .padding()
                }
                .tabItem {
                    Text("Dismissed (\(dismissedPRs.count + dismissedRequests.count))")
                }
            }
        }
        .frame(width: 700, height: 500)
    }
}

struct SnoozedDismissedRow: View {
    let title: String
    let repo: String
    let url: String
    let onRestore: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Button(action: {
                    if let url = URL(string: url) {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                .buttonStyle(PlainButtonStyle())
                .hoverCursor(.pointingHand)

                Text(repo)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Restore") {
                onRestore()
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

