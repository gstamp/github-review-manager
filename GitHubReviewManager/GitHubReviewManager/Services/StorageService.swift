import Foundation

class StorageService {
    static let shared = StorageService()

    private let userDefaults = UserDefaults.standard
    private let dismissedKey = "dismissedPRs"
    private let seenReviewsKey = "seenReviewIds"
    private let seenReviewRequestsKey = "seenReviewRequestIds"
    private let snoozedKey = "snoozedPRs"

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

    // MARK: - Snooze Tracking

    /// Load snoozed PR IDs with their expiration dates
    func loadSnoozedPrs() -> Dictionary<Int, Date> {
        guard let snoozedDict = userDefaults.dictionary(forKey: snoozedKey) as? [String: Double] else {
            return Dictionary<Int, Date>()
        }

        var result: Dictionary<Int, Date> = [:]
        for (key, timestamp) in snoozedDict {
            if let prId = Int(key) {
                let expirationDate = Date(timeIntervalSince1970: timestamp)
                // Only include if not expired
                if expirationDate > Date() {
                    result[prId] = expirationDate
                }
            }
        }
        return result
    }

    /// Save snoozed PR IDs with expiration dates
    private func saveSnoozedPrs(_ snoozed: Dictionary<Int, Date>) {
        // Clean up expired entries before saving
        let now = Date()
        let activeSnoozes = snoozed.filter { $0.value > now }

        var dict: [String: Double] = [:]
        for (prId, expirationDate) in activeSnoozes {
            dict[String(prId)] = expirationDate.timeIntervalSince1970
        }
        userDefaults.set(dict, forKey: snoozedKey)
    }

    /// Snooze a PR until a specific date
    func snoozePr(_ prId: Int, until expirationDate: Date) {
        var snoozed = loadSnoozedPrs()
        snoozed[prId] = expirationDate
        saveSnoozedPrs(snoozed)
    }

    /// Check if a PR is currently snoozed (and not expired)
    func isPrSnoozed(_ prId: Int) -> Bool {
        let snoozed = loadSnoozedPrs()
        return snoozed[prId] != nil
    }

    /// Filter out snoozed PRs that haven't expired
    func filterSnoozed<T: Identifiable>(_ prs: [T]) -> [T] where T.ID == Int {
        let snoozed = loadSnoozedPrs()
        let snoozedIds = Set(snoozed.keys)
        return prs.filter { !snoozedIds.contains($0.id) }
    }

    /// Get count of snoozed PRs
    func getSnoozedCount() -> Int {
        return loadSnoozedPrs().count
    }

    /// Get count of dismissed PRs
    func getDismissedCount() -> Int {
        return loadDismissedPrs().count
    }

    /// Get list of snoozed PR IDs
    func getSnoozedPRIds() -> [Int] {
        return Array(loadSnoozedPrs().keys)
    }

    /// Get list of dismissed PR IDs
    func getDismissedPRIds() -> [Int] {
        return Array(loadDismissedPrs())
    }

    /// Remove snooze from a PR (unsnooze)
    func unsnoozePr(_ prId: Int) {
        var snoozed = loadSnoozedPrs()
        snoozed.removeValue(forKey: prId)
        saveSnoozedPrs(snoozed)
    }

    /// Remove dismiss from a PR (undismiss)
    func undismissPr(_ prId: Int) {
        var dismissedIds = loadDismissedPrs()
        dismissedIds.remove(prId)
        saveDismissedPrs(dismissedIds)
    }
}

