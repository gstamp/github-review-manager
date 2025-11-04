import Foundation

class StorageService {
    static let shared = StorageService()

    private let userDefaults = UserDefaults.standard
    private let dismissedKey = "dismissedPRs"

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
}

