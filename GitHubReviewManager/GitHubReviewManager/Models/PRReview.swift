import Foundation

struct PRReview: Codable, Identifiable {
    let id: Int
    let number: Int
    let title: String
    let url: String
    let state: PRState
    let reviewStatus: ReviewStatus
    let author: String
    let createdAt: String
    let updatedAt: String
}

enum PRState: String, Codable {
    case open
    case closed
    case merged
}

enum ReviewStatus: String, Codable {
    case waiting
    case approved
    case changesRequested = "changes_requested"
    case commented
}

