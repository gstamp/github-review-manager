import Foundation

struct PRSummary: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let url: String
    let state: PRState
    let reviewStatus: ReviewStatus
    let author: String
    let repoOwner: String
    let repoName: String
    let createdAt: String
    let updatedAt: String
    let readyAt: String?
    let daysSinceReady: Double?
    let statusState: StatusState?
    let mergeableState: MergeableState?
    let graphQLId: String
    let mergeQueueEntry: MergeQueueEntryInfo?
    let isDraft: Bool

    var mergeable: Bool? {
        guard let state = mergeableState else { return nil }
        return state == .mergeable
    }

    var hasConflicts: Bool {
        return mergeableState == .conflicting
    }

    var isSnoozed: Bool { false }
    var isDismissed: Bool { false }

    func withStatus(isSnoozed: Bool, isDismissed: Bool) -> PRSummaryWithStatus {
        PRSummaryWithStatus(pr: self, isSnoozed: isSnoozed, isDismissed: isDismissed)
    }

    func withUpdatedState(_ serverState: SinglePRState) -> PRSummary {
        PRSummary(
            id: id,
            number: number,
            title: title,
            url: url,
            state: serverState.state,
            reviewStatus: serverState.reviewStatus,
            author: author,
            repoOwner: repoOwner,
            repoName: repoName,
            createdAt: createdAt,
            updatedAt: updatedAt,
            readyAt: readyAt,
            daysSinceReady: daysSinceReady,
            statusState: serverState.statusState,
            mergeableState: serverState.mergeableState,
            graphQLId: graphQLId,
            mergeQueueEntry: serverState.mergeQueueEntry,
            isDraft: isDraft
        )
    }
}

struct PRSummaryWithStatus: Identifiable {
    let pr: PRSummary
    let isSnoozed: Bool
    let isDismissed: Bool

    var id: Int { pr.id }
    var number: Int { pr.number }
    var title: String { pr.title }
    var url: String { pr.url }
    var state: PRState { pr.state }
    var reviewStatus: ReviewStatus { pr.reviewStatus }
    var author: String { pr.author }
    var repoOwner: String { pr.repoOwner }
    var repoName: String { pr.repoName }
    var createdAt: String { pr.createdAt }
    var updatedAt: String { pr.updatedAt }
    var readyAt: String? { pr.readyAt }
    var daysSinceReady: Double? { pr.daysSinceReady }
    var statusState: StatusState? { pr.statusState }
    var mergeableState: MergeableState? { pr.mergeableState }
    var graphQLId: String { pr.graphQLId }
    var mergeQueueEntry: MergeQueueEntryInfo? { pr.mergeQueueEntry }
    var isDraft: Bool { pr.isDraft }
    var mergeable: Bool? { pr.mergeable }
    var hasConflicts: Bool { pr.hasConflicts }
}

enum StatusState: String, Codable {
    case success
    case failure
    case pending
    case error
}

enum MergeableState: String, Codable {
    case mergeable = "MERGEABLE"
    case conflicting = "CONFLICTING"
    case unknown = "UNKNOWN"
}

