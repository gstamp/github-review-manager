import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = PRViewModel()
    @State private var selectedTab: TabIdentifier = .myPRs
    @State private var showSnoozePicker = false
    @State private var snoozedPRId: Int?
    @State private var showLoginView = false
    @State private var filterStates: [String: PRFilterState] = [:]

    private let storageService = StorageService.shared

    enum TabIdentifier: Hashable {
        case myPRs
        case category(String)

        var storageKey: String {
            switch self {
            case .myPRs:
                return "myPRs"
            case .category(let category):
                return "category_\(category)"
            }
        }
    }

    private func filterStateBinding(for tabId: String) -> Binding<PRFilterState> {
        Binding(
            get: { filterStates[tabId] ?? PRFilterState() },
            set: { filterStates[tabId] = $0 }
        )
    }

    private func saveFilterState(for tabId: String) {
        if let state = filterStates[tabId] {
            storageService.saveFilterState(state, for: tabId)
        }
    }

    private func loadAllFilterStates() {
        filterStates["myPRs"] = storageService.loadFilterState(for: "myPRs")
        for group in viewModel.sortedCategoryGroups {
            let key = "category_\(group.category)"
            filterStates[key] = storageService.loadFilterState(for: key)
        }
    }

    private func filteredMyPRsCount() -> Int {
        let state = filterStates["myPRs"] ?? PRFilterState()
        return state.filter(viewModel.allUserPRsForDisplay).count
    }

    private func filteredCategoryCount(for category: String) -> Int {
        let tabKey = "category_\(category)"
        let state = filterStates[tabKey] ?? PRFilterState()
        return state.filter(viewModel.allRequestsForDisplay(category: category)).count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GitHub PR Reviews")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                HStack(spacing: 8) {
                    if viewModel.isRefreshing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                    }

                    Button("Refresh") {
                        Task {
                            await viewModel.loadData(forceRefresh: true)
                        }
                    }
                    .disabled(viewModel.loading || viewModel.isRefreshing)
                    .hoverCursor(.pointingHand)

                    if viewModel.isAuthenticated {
                        Button("Sign Out") {
                            viewModel.signOut()
                            showLoginView = true
                        }
                        .hoverCursor(.pointingHand)
                    }

                    Button("Quit") {
                        NSApplication.shared.terminate(nil)
                    }
                    .hoverCursor(.pointingHand)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Content
            if viewModel.loading && viewModel.userPRs.isEmpty && viewModel.reviewRequests.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if let error = viewModel.error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding()
                }

                TabView(selection: $selectedTab) {
                    // My PRs Tab
                    PRListView(
                        prs: viewModel.allUserPRsForDisplay,
                        emptyMessage: "No open PRs found",
                        onCopy: { pr in
                            SlackFormatter.copyToClipboard(SlackFormatter.formatMessage(pr: pr))
                        },
                        onDismiss: { pr in
                            Task {
                                await viewModel.dismissPR(pr.id)
                            }
                        },
                        onSnooze: { pr in
                            snoozedPRId = pr.id
                            showSnoozePicker = true
                        },
                        onApprove: nil,
                        onMerge: { pr in
                            Task {
                                await viewModel.mergePR(pr.pr)
                            }
                        },
                        showCopyAll: !viewModel.userPRs.isEmpty,
                        onCopyAll: { visiblePRs in
                            let messages = visiblePRs.map { SlackFormatter.formatMessage(pr: $0) }
                            SlackFormatter.copyToClipboard(messages.joined(separator: "\n"))
                        },
                        draftCount: viewModel.getDraftCount(for: viewModel.userPRs),
                        snoozedCount: viewModel.getSnoozedCount(for: viewModel.userPRs),
                        dismissedCount: viewModel.getDismissedCount(for: viewModel.userPRs),
                        mergingPRIds: viewModel.mergingPRIds,
                        pendingActions: viewModel.pendingActions,
                        filterState: filterStateBinding(for: "myPRs"),
                        onFilterChanged: { saveFilterState(for: "myPRs") },
                        showDraftsToggle: true,
                        onUnsnooze: { pr in
                            Task {
                                await viewModel.unsnoozePR(pr.id)
                            }
                        },
                        onUndismiss: { pr in
                            Task {
                                await viewModel.undismissPR(pr.id)
                            }
                        }
                    )
                    .tabItem {
                        Text("My PRs (\(filteredMyPRsCount()))")
                    }
                    .tag(TabIdentifier.myPRs)

                    // Category Tabs
                    ForEach(viewModel.sortedCategoryGroups, id: \.category) { group in
                        let tabKey = "category_\(group.category)"
                        PRListView(
                            prs: viewModel.allRequestsForDisplay(category: group.category),
                            emptyMessage: "No review requests found",
                            onCopy: { request in
                                SlackFormatter.copyToClipboard(SlackFormatter.formatMessage(pr: request))
                            },
                            onDismiss: { request in
                                Task {
                                    await viewModel.dismissPR(request.id)
                                }
                            },
                            onSnooze: { request in
                                snoozedPRId = request.id
                                showSnoozePicker = true
                            },
                            onApprove: { request in
                                Task {
                                    await viewModel.approvePR(request.request)
                                }
                            },
                            onMerge: { request in
                                Task {
                                    await viewModel.requestMergePR(request.request)
                                }
                            },
                        showCopyAll: !group.requests.isEmpty,
                        onCopyAll: { visibleRequests in
                            let messages = visibleRequests.map { SlackFormatter.formatMessage(pr: $0) }
                            SlackFormatter.copyToClipboard(messages.joined(separator: "\n"))
                        },
                            snoozedCount: viewModel.getSnoozedCount(for: group.requests, category: group.category),
                            dismissedCount: viewModel.getDismissedCount(for: group.requests, category: group.category),
                            mergingPRIds: viewModel.mergingPRIds,
                            pendingActions: viewModel.pendingActions,
                            filterState: filterStateBinding(for: tabKey),
                            onFilterChanged: { saveFilterState(for: tabKey) },
                            onUnsnooze: { request in
                                Task {
                                    await viewModel.unsnoozePR(request.id)
                                }
                            },
                            onUndismiss: { request in
                                Task {
                                    await viewModel.undismissPR(request.id)
                                }
                            }
                        )
                        .tabItem {
                            Text("\(group.categoryLabel) (\(filteredCategoryCount(for: group.category)))")
                        }
                        .tag(TabIdentifier.category(group.category))
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
        .onAppear {
            Task {
                await viewModel.loadData()
                loadAllFilterStates()
                // Show login if no token available after load attempt
                if !viewModel.isAuthenticated {
                    showLoginView = true
                }
            }
        }
        .sheet(isPresented: $showLoginView) {
            LoginView(
                onSuccess: {
                    showLoginView = false
                    Task {
                        await viewModel.loadData(forceRefresh: true)
                    }
                },
                onCancel: {
                    showLoginView = false
                }
            )
        }
        .alert("Confirm Merge", isPresented: $viewModel.showMergeConfirmation) {
            Button("Cancel", role: .cancel) {
                viewModel.cancelMergePR()
            }
            Button("Merge", role: .destructive) {
                Task {
                    await viewModel.confirmMergePR()
                }
            }
        } message: {
            Text("This is someone else's PR. Are you sure you wish to merge it?")
        }
        .alert("Merge Failed", isPresented: $viewModel.showMergeError) {
            Button("OK", role: .cancel) {
                viewModel.dismissMergeError()
            }
        } message: {
            if let error = viewModel.mergeError {
                Text(error)
            } else {
                Text("An unknown error occurred while merging the PR.")
            }
        }
        .sheet(isPresented: $showSnoozePicker) {
            SnoozePicker(
                onSelect: { duration in
                    if let prId = snoozedPRId {
                        showSnoozePicker = false
                        let prIdToSnooze = prId
                        snoozedPRId = nil
                        Task {
                            await viewModel.snoozePR(prIdToSnooze, duration: duration)
                        }
                    }
                },
                onCancel: {
                    showSnoozePicker = false
                    snoozedPRId = nil
                }
            )
        }
    }
}

// MARK: - ViewModel

@MainActor
class PRViewModel: ObservableObject {
    @Published var userPRs: [PRSummary] = []
    @Published var reviewRequests: [ReviewRequest] = []
    @Published var loading = false
    @Published var isRefreshing = false
    @Published var error: String?
    @Published var pendingMergeRequest: ReviewRequest?
    @Published var showMergeConfirmation = false
    @Published var mergingPRIds: Set<Int> = []
    @Published var mergeError: String?
    @Published var showMergeError = false
    @Published var isAuthenticated = false
    @Published var pendingActions: Set<Int> = []

    private var allUserPRs: [PRSummary] = [] // All PRs including snoozed/dismissed
    private var allReviewRequests: [ReviewRequest] = [] // All requests including snoozed/dismissed

    private let githubService = GitHubService.shared
    private let storageService = StorageService.shared
    private let authService = AuthService.shared
    private let notificationService = NotificationService.shared
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 5 * 60 // 5 minutes, matching cacheTTL

    var myPRsCount: Int {
        userPRs.count
    }

    var allUserPRsForDisplay: [PRSummaryWithStatus] {
        let snoozedIds = Set(storageService.getSnoozedPRIds())
        let dismissedIds = Set(storageService.getDismissedPRIds())
        return allUserPRs.map { pr in
            pr.withStatus(
                isSnoozed: snoozedIds.contains(pr.id),
                isDismissed: dismissedIds.contains(pr.id)
            )
        }
    }

    func allRequestsForDisplay(category: String) -> [ReviewRequestWithStatus] {
        let snoozedIds = Set(storageService.getSnoozedPRIds())
        let dismissedIds = Set(storageService.getDismissedPRIds())
        return allReviewRequests
            .filter { $0.reviewCategory == category }
            .map { request in
                request.withStatus(
                    isSnoozed: snoozedIds.contains(request.id),
                    isDismissed: dismissedIds.contains(request.id)
                )
            }
    }

    func signOut() {
        authService.clearToken()
        githubService.setToken(nil)
        isAuthenticated = false
        userPRs = []
        reviewRequests = []
        allUserPRs = []
        allReviewRequests = []
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func getSnoozedCount(for prs: [PRSummary]) -> Int {
        let snoozedIds = Set(storageService.getSnoozedPRIds())
        let allPRIds = Set(allUserPRs.map { $0.id })
        return snoozedIds.intersection(allPRIds).count
    }

    func getDismissedCount(for prs: [PRSummary]) -> Int {
        let dismissedIds = Set(storageService.getDismissedPRIds())
        let allPRIds = Set(allUserPRs.map { $0.id })
        return dismissedIds.intersection(allPRIds).count
    }

    func getSnoozedCount(for requests: [ReviewRequest]) -> Int {
        let snoozedIds = Set(storageService.getSnoozedPRIds())
        let allRequestIds = Set(allReviewRequests.map { $0.id })
        return snoozedIds.intersection(allRequestIds).count
    }

    func getDismissedCount(for requests: [ReviewRequest]) -> Int {
        let dismissedIds = Set(storageService.getDismissedPRIds())
        let allRequestIds = Set(allReviewRequests.map { $0.id })
        return dismissedIds.intersection(allRequestIds).count
    }

    func getSnoozedCount(for requests: [ReviewRequest], category: String) -> Int {
        let snoozedIds = Set(storageService.getSnoozedPRIds())
        let categoryRequestIds = Set(allReviewRequests.filter { $0.reviewCategory == category }.map { $0.id })
        return snoozedIds.intersection(categoryRequestIds).count
    }

    func getDismissedCount(for requests: [ReviewRequest], category: String) -> Int {
        let dismissedIds = Set(storageService.getDismissedPRIds())
        let categoryRequestIds = Set(allReviewRequests.filter { $0.reviewCategory == category }.map { $0.id })
        return dismissedIds.intersection(categoryRequestIds).count
    }

    func getDraftCount(for prs: [PRSummary]) -> Int {
        allUserPRs.filter { $0.isDraft }.count
    }

    var categoryGroups: [CategoryGroup] {
        // Group reviews by category
        var categories: [String: [ReviewRequest]] = [:]
        reviewRequests.forEach { request in
            let category = request.reviewCategory
            if categories[category] == nil {
                categories[category] = []
            }
            categories[category]?.append(request)
        }

        return categories.map { category, requests in
            let categoryLabel: String = {
                switch category {
                case "human":
                    return "From Humans"
                case "buildagencygitapitoken":
                    return "Promotions"
                case "snyk-io":
                    return "Snyk-io"
                case "renovate":
                    return "Renovate"
                default:
                    return category.prefix(1).uppercased() + category.dropFirst()
                }
            }()

            return CategoryGroup(category: category, categoryLabel: categoryLabel, requests: requests)
        }
    }

    var sortedCategoryGroups: [CategoryGroup] {
        // Sort categories: human first, then alphabetically
        categoryGroups.sorted { group1, group2 in
            let a = group1.category
            let b = group2.category

            // Human always first
            if a == "human" { return true }
            if b == "human" { return false }

            // Sort alphabetically
            return a < b
        }
    }

    func loadData(forceRefresh: Bool = false) async {
        let hasExistingData = !userPRs.isEmpty || !reviewRequests.isEmpty

        if hasExistingData {
            isRefreshing = true
        } else {
            loading = true
        }
        error = nil

        // Initialize auth if needed
        if !githubService.hasToken() {
            print("No token found, attempting to get GitHub token...")
            if let token = await authService.getGitHubToken() {
                print("Got token from auth service")
                githubService.setToken(token)
                isAuthenticated = true
            } else {
                isAuthenticated = false
            }
        } else {
            print("Token already available")
            isAuthenticated = true
        }

        print("Loading data (forceRefresh: \(forceRefresh))...")
        do {
            let (prs, requests) = try await (
                githubService.getUserOpenPRs(forceRefresh: forceRefresh),
                githubService.getReviewRequests(forceRefresh: forceRefresh)
            )

            // Store all PRs for count calculations
            allUserPRs = prs
            allReviewRequests = requests

            // Filter out dismissed and snoozed PRs for display
            userPRs = storageService.filterDismissed(prs)
            userPRs = storageService.filterSnoozed(userPRs)
            reviewRequests = storageService.filterDismissed(requests)
            reviewRequests = storageService.filterSnoozed(reviewRequests)

            // Detect and notify about new reviews
            do {
                let newReviews = try await githubService.detectNewReviews()
                for review in newReviews {
                    notificationService.sendReviewNotification(
                        prNumber: review.prNumber,
                        prTitle: review.prTitle,
                        reviewState: review.reviewState
                    )
                    // Mark review as seen after sending notification
                    storageService.markReviewAsSeen(review.reviewId)
                }
            } catch {
                // Don't fail the entire load if review detection fails
                print("Error detecting new reviews: \(error)")
            }

            // Detect and notify about new review requests
            do {
                let newReviewRequests = try await githubService.detectNewReviewRequests()
                for request in newReviewRequests {
                    notificationService.sendReviewRequestNotification(
                        prNumber: request.prNumber,
                        prTitle: request.prTitle,
                        category: request.reviewCategory
                    )
                    // Mark review request as seen after sending notification
                    storageService.markReviewRequestAsSeen(request.prId)
                }
            } catch {
                // Don't fail the entire load if review request detection fails
                print("Error detecting new review requests: \(error)")
            }
        } catch let err {
            error = err.localizedDescription
        }

        loading = false
        isRefreshing = false

        // Start or restart automatic refresh timer
        startRefreshTimer()
    }

    private func startRefreshTimer() {
        // Invalidate existing timer if any
        refreshTimer?.invalidate()

        // Create new timer that fires every 5 minutes
        // Use .common modes so it runs even when popover is open (NSEventTrackingRunLoopMode)
        let timer = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.loadData(forceRefresh: true)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func dismissPR(_ prId: Int) async {
        storageService.dismissPr(prId)
        // Optimistically remove from visible lists immediately
        userPRs.removeAll { $0.id == prId }
        reviewRequests.removeAll { $0.id == prId }
        // Invalidate cache for next refresh, but don't reload now
        githubService.invalidateCache()
    }

    func snoozePR(_ prId: Int, duration: SnoozeDuration) async {
        let expirationDate = duration.expirationDate
        storageService.snoozePr(prId, until: expirationDate)
        // Optimistically remove from visible lists immediately
        userPRs.removeAll { $0.id == prId }
        reviewRequests.removeAll { $0.id == prId }
        // Invalidate cache for next refresh, but don't reload now
        githubService.invalidateCache()
    }

    func unsnoozePR(_ prId: Int) async {
        storageService.unsnoozePr(prId)
        // Re-add to visible lists from allUserPRs/allReviewRequests
        if let pr = allUserPRs.first(where: { $0.id == prId }) {
            if !userPRs.contains(where: { $0.id == prId }) {
                userPRs.append(pr)
            }
        }
        if let request = allReviewRequests.first(where: { $0.id == prId }) {
            if !reviewRequests.contains(where: { $0.id == prId }) {
                reviewRequests.append(request)
            }
        }
        githubService.invalidateCache()
    }

    func undismissPR(_ prId: Int) async {
        storageService.undismissPr(prId)
        // Re-add to visible lists from allUserPRs/allReviewRequests
        if let pr = allUserPRs.first(where: { $0.id == prId }) {
            if !userPRs.contains(where: { $0.id == prId }) {
                userPRs.append(pr)
            }
        }
        if let request = allReviewRequests.first(where: { $0.id == prId }) {
            if !reviewRequests.contains(where: { $0.id == prId }) {
                reviewRequests.append(request)
            }
        }
        githubService.invalidateCache()
    }

    func approvePR(_ reviewRequest: ReviewRequest) async {
        pendingActions.insert(reviewRequest.id)
        defer { pendingActions.remove(reviewRequest.id) }

        do {
            print("Attempting to approve PR #\(reviewRequest.number) (\(reviewRequest.repoOwner)/\(reviewRequest.repoName))")
            print("Using GraphQL ID: \(reviewRequest.graphQLId)")
            try await githubService.approvePR(pullRequestId: reviewRequest.graphQLId)
            print("Successfully approved PR #\(reviewRequest.number)")

            // Verify with single-PR query (lightweight)
            if let newState = try await githubService.getPRState(graphQLId: reviewRequest.graphQLId) {
                updateLocalReviewRequestState(reviewRequest.id, with: newState)
            } else {
                removePRFromLocalState(reviewRequest.id)
            }
            githubService.invalidateCache()
        } catch {
            print("Error approving PR #\(reviewRequest.number) (\(reviewRequest.repoOwner)/\(reviewRequest.repoName)): \(error)")
            if let githubError = error as? GitHubError {
                print("GitHub error details: \(githubError.localizedDescription)")
            }
        }
    }

    func mergePR(_ pr: PRSummary) async {
        let prId = pr.id

        mergingPRIds.insert(prId)
        pendingActions.insert(prId)

        defer {
            mergingPRIds.remove(prId)
            pendingActions.remove(prId)
        }

        do {
            let mergeMethod = try await githubService.getRepositoryMergeMethod(
                owner: pr.repoOwner,
                repo: pr.repoName
            )
            try await githubService.mergePR(
                pullRequestId: pr.graphQLId,
                mergeMethod: mergeMethod,
                owner: pr.repoOwner,
                repo: pr.repoName
            )
            print("Successfully merged PR #\(pr.number)")

            // Verify with single-PR query - if merged, remove from list
            if let newState = try? await githubService.getPRState(graphQLId: pr.graphQLId) {
                if newState.merged || newState.state == .merged || newState.state == .closed {
                    removePRFromLocalState(prId)
                } else {
                    updateLocalUserPRState(prId, with: newState)
                }
            } else {
                removePRFromLocalState(prId)
            }
            githubService.invalidateCache()
        } catch GitHubError.mergeQueued {
            print("PR #\(pr.number) successfully enqueued to merge queue")
            // Verify queue position with single-PR query
            if let newState = try? await githubService.getPRState(graphQLId: pr.graphQLId) {
                updateLocalUserPRState(prId, with: newState)
            }
            githubService.invalidateCache()
        } catch {
            print("Error merging PR #\(pr.number) (\(pr.repoOwner)/\(pr.repoName)): \(error)")

            let errorMessage: String = {
                if let githubError = error as? GitHubError {
                    return githubError.localizedDescription
                } else {
                    return error.localizedDescription
                }
            }()

            let fullErrorMessage = "Failed to merge PR #\(pr.number): \(pr.title)\n\n\(errorMessage)"
            mergeError = fullErrorMessage
            showMergeError = true
        }
    }

    func requestMergePR(_ reviewRequest: ReviewRequest) async {
        // Check if this is someone else's PR from a human
        do {
            let currentUsername = try await githubService.getUsername()
            let isHumanPR = reviewRequest.reviewCategory == "human"
            let isSomeoneElsesPR = reviewRequest.author.lowercased() != currentUsername.lowercased()

            if isHumanPR && isSomeoneElsesPR {
                // Show confirmation dialog
                pendingMergeRequest = reviewRequest
                showMergeConfirmation = true
            } else {
                // No confirmation needed, merge directly
                await mergePR(reviewRequest)
            }
        } catch {
            // If we can't get username, proceed without confirmation
            print("Could not get username for merge confirmation: \(error)")
            await mergePR(reviewRequest)
        }
    }

    func confirmMergePR() async {
        guard let request = pendingMergeRequest else { return }
        pendingMergeRequest = nil
        showMergeConfirmation = false
        await mergePR(request)
    }

    func cancelMergePR() {
        pendingMergeRequest = nil
        showMergeConfirmation = false
    }

    func mergePR(_ reviewRequest: ReviewRequest) async {
        let prId = reviewRequest.id

        mergingPRIds.insert(prId)
        pendingActions.insert(prId)

        defer {
            mergingPRIds.remove(prId)
            pendingActions.remove(prId)
        }

        do {
            let mergeMethod = try await githubService.getRepositoryMergeMethod(
                owner: reviewRequest.repoOwner,
                repo: reviewRequest.repoName
            )
            try await githubService.mergePR(
                pullRequestId: reviewRequest.graphQLId,
                mergeMethod: mergeMethod,
                owner: reviewRequest.repoOwner,
                repo: reviewRequest.repoName
            )
            print("Successfully merged PR #\(reviewRequest.number)")

            // Verify with single-PR query - if merged, remove from list
            if let newState = try? await githubService.getPRState(graphQLId: reviewRequest.graphQLId) {
                if newState.merged || newState.state == .merged || newState.state == .closed {
                    removePRFromLocalState(prId)
                } else {
                    updateLocalReviewRequestState(prId, with: newState)
                }
            } else {
                removePRFromLocalState(prId)
            }
            githubService.invalidateCache()
        } catch GitHubError.mergeQueued {
            print("PR #\(reviewRequest.number) successfully enqueued to merge queue")
            // Verify queue position with single-PR query
            if let newState = try? await githubService.getPRState(graphQLId: reviewRequest.graphQLId) {
                updateLocalReviewRequestState(prId, with: newState)
            }
            githubService.invalidateCache()
        } catch {
            print("Error merging PR #\(reviewRequest.number) (\(reviewRequest.repoOwner)/\(reviewRequest.repoName)): \(error)")

            let errorMessage: String = {
                if let githubError = error as? GitHubError {
                    return githubError.localizedDescription
                } else {
                    return error.localizedDescription
                }
            }()

            let fullErrorMessage = "Failed to merge PR #\(reviewRequest.number): \(reviewRequest.title)\n\n\(errorMessage)"
            mergeError = fullErrorMessage
            showMergeError = true
        }
    }

    func dismissMergeError() {
        mergeError = nil
        showMergeError = false
    }

    // MARK: - Surgical Local State Updates

    private func updateLocalReviewRequestState(_ prId: Int, with serverState: SinglePRState) {
        if let index = reviewRequests.firstIndex(where: { $0.id == prId }) {
            reviewRequests[index] = reviewRequests[index].withUpdatedState(serverState)
        }
        if let index = allReviewRequests.firstIndex(where: { $0.id == prId }) {
            allReviewRequests[index] = allReviewRequests[index].withUpdatedState(serverState)
        }
    }

    private func updateLocalUserPRState(_ prId: Int, with serverState: SinglePRState) {
        if let index = userPRs.firstIndex(where: { $0.id == prId }) {
            userPRs[index] = userPRs[index].withUpdatedState(serverState)
        }
        if let index = allUserPRs.firstIndex(where: { $0.id == prId }) {
            allUserPRs[index] = allUserPRs[index].withUpdatedState(serverState)
        }
    }

    private func removePRFromLocalState(_ prId: Int) {
        userPRs.removeAll { $0.id == prId }
        allUserPRs.removeAll { $0.id == prId }
        reviewRequests.removeAll { $0.id == prId }
        allReviewRequests.removeAll { $0.id == prId }
    }
}

struct CategoryGroup {
    let category: String
    let categoryLabel: String
    let requests: [ReviewRequest]
}

