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

    var mergeable: Bool? {
        guard let state = mergeableState else { return nil }
        return state == .mergeable
    }

    var hasConflicts: Bool {
        return mergeableState == .conflicting
    }
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

