import Foundation

enum PRFilterType: String, Codable, CaseIterable {
    case failed
    case passed
    case approved
    case unapproved
    case mergeable

    var displayName: String {
        switch self {
        case .failed: return "Failed"
        case .passed: return "Passed"
        case .approved: return "Approved"
        case .unapproved: return "Unapproved"
        case .mergeable: return "Mergeable"
        }
    }

    var mutuallyExclusiveWith: PRFilterType? {
        switch self {
        case .approved: return .unapproved
        case .unapproved: return .approved
        case .failed: return .passed
        case .passed: return .failed
        case .mergeable: return nil
        }
    }
}

struct PRFilterState: Codable, Equatable {
    var activeFilters: Set<PRFilterType>
    var showDrafts: Bool
    var showSnoozed: Bool
    var showDismissed: Bool

    init(activeFilters: Set<PRFilterType> = [], showDrafts: Bool = false, showSnoozed: Bool = false, showDismissed: Bool = false) {
        self.activeFilters = activeFilters
        self.showDrafts = showDrafts
        self.showSnoozed = showSnoozed
        self.showDismissed = showDismissed
    }

    var isEmpty: Bool {
        activeFilters.isEmpty && !showDrafts && !showSnoozed && !showDismissed
    }

    mutating func toggle(_ filter: PRFilterType) {
        if activeFilters.contains(filter) {
            activeFilters.remove(filter)
        } else {
            // Remove mutually exclusive filter if present
            if let exclusive = filter.mutuallyExclusiveWith {
                activeFilters.remove(exclusive)
            }
            activeFilters.insert(filter)
        }
    }

    func isActive(_ filter: PRFilterType) -> Bool {
        activeFilters.contains(filter)
    }

    func matches<PR: PRRowItem>(_ pr: PR) -> Bool {
        // Filter out draft PRs unless showDrafts is enabled
        if pr.isDraft && !showDrafts {
            return false
        }

        // Filter out snoozed PRs unless showSnoozed is enabled
        if pr.isSnoozed && !showSnoozed {
            return false
        }

        // Filter out dismissed PRs unless showDismissed is enabled
        if pr.isDismissed && !showDismissed {
            return false
        }

        // If no active filters, show everything (that passes above filters)
        if activeFilters.isEmpty {
            return true
        }

        // AND logic: PR must match ALL active filters
        for filter in activeFilters {
            if !matchesFilter(pr, filter: filter) {
                return false
            }
        }
        return true
    }

    private func matchesFilter<PR: PRRowItem>(_ pr: PR, filter: PRFilterType) -> Bool {
        switch filter {
        case .failed:
            return pr.statusState == .failure || pr.statusState == .error
        case .passed:
            return pr.statusState == .success
        case .approved:
            return pr.reviewStatus == .approved
        case .unapproved:
            return pr.reviewStatus != .approved
        case .mergeable:
            return pr.mergeQueueEntry == nil
                && pr.reviewStatus == .approved
                && pr.mergeable == true
                && pr.statusState != .failure
                && pr.statusState != .error
        }
    }

    func filter<PR: PRRowItem>(_ prs: [PR]) -> [PR] {
        prs.filter { matches($0) }
            .sorted { pr1, pr2 in
                // Sort by repository name first (ascending)
                let repo1 = pr1.repoName.lowercased()
                let repo2 = pr2.repoName.lowercased()
                if repo1 != repo2 {
                    return repo1 < repo2
                }
                // Then by age (descending - older PRs first)
                return pr1.createdAt < pr2.createdAt
            }
    }
}

