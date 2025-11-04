import Foundation

class StorageService {
    static let shared = StorageService()

    private let userDefaults = UserDefaults.standard
    private let dismissedKey = "dismissedPRs"
    private let seenReviewsKey = "seenReviewIds"
    private let seenReviewRequestsKey = "seenReviewRequestIds"

    private init() {}

    /// Load dismissed PR IDs from storage
    func loadDismissedPrs() -> Set<Int> {
        guard let dismissedIds = userDefaults.array(forKey: dismissedKey) as? [Int] else {
            return Set<Int>()
        }
        return Set(dismissedIds)
    }

    /// Save dismissed PR IDs to storage
    private func saveDismissedPrs(_ ids: Set<Int>) {
        userDefaults.set(Array(ids), forKey: dismissedKey)
    }

    /// Dismiss a PR by ID
    func dismissPr(_ prId: Int) {
        var dismissedIds = loadDismissedPrs()
        dismissedIds.insert(prId)
        saveDismissedPrs(dismissedIds)
    }

    /// Check if a PR is dismissed
    func isPrDismissed(_ prId: Int) -> Bool {
        return loadDismissedPrs().contains(prId)
    }

    /// Filter out dismissed PRs from an array
    func filterDismissed<T: Identifiable>(_ prs: [T]) -> [T] where T.ID == Int {
        let dismissedIds = loadDismissedPrs()
        return prs.filter { !dismissedIds.contains($0.id) }
    }

    // MARK: - Review Tracking

    /// Load seen review IDs from storage
    func loadSeenReviewIds() -> Set<String> {
        guard let reviewIds = userDefaults.array(forKey: seenReviewsKey) as? [String] else {
            return Set<String>()
        }
        return Set(reviewIds)
    }

    /// Save seen review IDs to storage
    private func saveSeenReviewIds(_ ids: Set<String>) {
        userDefaults.set(Array(ids), forKey: seenReviewsKey)
    }

    /// Mark a review as seen by ID
    func markReviewAsSeen(_ reviewId: String) {
        var seenIds = loadSeenReviewIds()
        seenIds.insert(reviewId)
        saveSeenReviewIds(seenIds)
    }

    /// Check if a review has been seen
    func hasSeenReview(_ reviewId: String) -> Bool {
        return loadSeenReviewIds().contains(reviewId)
    }

    // MARK: - Review Request Tracking

    /// Load seen review request IDs from storage
    func loadSeenReviewRequestIds() -> Set<Int> {
        guard let requestIds = userDefaults.array(forKey: seenReviewRequestsKey) as? [Int] else {
            return Set<Int>()
        }
        return Set(requestIds)
    }

    /// Save seen review request IDs to storage
    private func saveSeenReviewRequestIds(_ ids: Set<Int>) {
        userDefaults.set(Array(ids), forKey: seenReviewRequestsKey)
    }

    /// Mark a review request as seen by PR ID
    func markReviewRequestAsSeen(_ prId: Int) {
        var seenIds = loadSeenReviewRequestIds()
        seenIds.insert(prId)
        saveSeenReviewRequestIds(seenIds)
    }

    /// Check if a review request has been seen
    func hasSeenReviewRequest(_ prId: Int) -> Bool {
        return loadSeenReviewRequestIds().contains(prId)
    }
}

