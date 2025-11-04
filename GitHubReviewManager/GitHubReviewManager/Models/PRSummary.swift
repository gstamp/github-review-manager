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
}

enum StatusState: String, Codable {
    case success
    case failure
    case pending
    case error
}

