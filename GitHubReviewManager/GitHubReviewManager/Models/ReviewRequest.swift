import Foundation

struct ReviewRequest: Codable, Identifiable {
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
    let reviewRequestedAt: String?
    let daysWaiting: Double?
    let requestedReviewer: String?
    let reviewCategory: String // PR author category: 'human' or bot name (e.g., 'snyk', 'renovate', 'buildagencygitapitoken')
    let statusState: StatusState?
    let graphQLId: String
    let mergeableState: MergeableState?
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

    func withStatus(isSnoozed: Bool, isDismissed: Bool) -> ReviewRequestWithStatus {
        ReviewRequestWithStatus(request: self, isSnoozed: isSnoozed, isDismissed: isDismissed)
    }
}

struct ReviewRequestWithStatus: Identifiable {
    let request: ReviewRequest
    let isSnoozed: Bool
    let isDismissed: Bool

    var id: Int { request.id }
    var number: Int { request.number }
    var title: String { request.title }
    var url: String { request.url }
    var state: PRState { request.state }
    var reviewStatus: ReviewStatus { request.reviewStatus }
    var author: String { request.author }
    var repoOwner: String { request.repoOwner }
    var repoName: String { request.repoName }
    var createdAt: String { request.createdAt }
    var updatedAt: String { request.updatedAt }
    var reviewRequestedAt: String? { request.reviewRequestedAt }
    var daysWaiting: Double? { request.daysWaiting }
    var requestedReviewer: String? { request.requestedReviewer }
    var reviewCategory: String { request.reviewCategory }
    var statusState: StatusState? { request.statusState }
    var graphQLId: String { request.graphQLId }
    var mergeableState: MergeableState? { request.mergeableState }
    var mergeQueueEntry: MergeQueueEntryInfo? { request.mergeQueueEntry }
    var isDraft: Bool { request.isDraft }
    var mergeable: Bool? { request.mergeable }
    var hasConflicts: Bool { request.hasConflicts }
}

