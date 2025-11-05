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
    let graphQLId: String // GitHub GraphQL node ID for mutations
    let mergeable: Bool? // Whether PR can be merged
}

