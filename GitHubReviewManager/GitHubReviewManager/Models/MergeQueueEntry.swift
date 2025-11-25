import Foundation

struct MergeQueueEntryInfo: Codable, Equatable {
    let state: MergeQueueState
    let position: Int?
}

enum MergeQueueState: String, Codable {
    case awaitingChecks = "AWAITING_CHECKS"
    case queued = "QUEUED"
    case locked = "LOCKED"
    case mergeable = "MERGEABLE"
    case unmergeable = "UNMERGEABLE"

    var displayText: String {
        switch self {
        case .awaitingChecks:
            return "awaiting checks"
        case .queued:
            return "queued"
        case .locked:
            return "merging"
        case .mergeable:
            return "ready"
        case .unmergeable:
            return "queue failed"
        }
    }
}

