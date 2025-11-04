import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var viewModel = PRViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("GitHub PR Reviews")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                HStack(spacing: 8) {
                    Button("Refresh") {
                        Task {
                            await viewModel.loadData(forceRefresh: true)
                        }
                    }
                    .disabled(viewModel.loading)
                    .hoverCursor(.pointingHand)

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
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if viewModel.loading {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else if let error = viewModel.error {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        // My Open PRs Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("My Open PRs")
                                    .font(.headline)

                                Spacer()

                                if !viewModel.userPRs.isEmpty {
                                    CopyAllButton {
                                        let messages = viewModel.userPRs.map { SlackFormatter.formatMessage(pr: $0) }
                                        SlackFormatter.copyToClipboard(messages.joined(separator: "\n"))
                                    }
                                }
                            }
                            .padding(.horizontal)

                            if viewModel.userPRs.isEmpty {
                                Text("No open PRs found")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(viewModel.userPRs) { pr in
                                    PRRow(pr: pr) {
                                        SlackFormatter.copyToClipboard(SlackFormatter.formatMessage(pr: pr))
                                    } onDismiss: {
                                        Task {
                                            await viewModel.dismissPR(pr.id)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .padding(.vertical)

                        Divider()

                        // Review Requests Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Review Requests")
                                .font(.headline)
                                .padding(.horizontal)

                            if viewModel.reviewRequests.isEmpty {
                                Text("No review requests found")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(viewModel.categoryGroups, id: \.category) { group in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(group.categoryLabel)
                                                .font(.subheadline)
                                                .fontWeight(.semibold)

                                            Spacer()

                                            if !group.requests.isEmpty {
                                                CopyAllButton {
                                                    let messages = group.requests.map { SlackFormatter.formatMessage(pr: $0) }
                                                    SlackFormatter.copyToClipboard(messages.joined(separator: "\n"))
                                                }
                                            }
                                        }
                                        .padding(.horizontal)

                                        ForEach(group.requests) { request in
                                            PRRow(pr: request) {
                                                SlackFormatter.copyToClipboard(SlackFormatter.formatMessage(pr: request))
                                            } onDismiss: {
                                                Task {
                                                    await viewModel.dismissPR(request.id)
                                                }
                                            }
                                            .padding(.horizontal)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
    }
}

// MARK: - ViewModel

@MainActor
class PRViewModel: ObservableObject {
    @Published var userPRs: [PRSummary] = []
    @Published var reviewRequests: [ReviewRequest] = []
    @Published var loading = false
    @Published var error: String?

    private let githubService = GitHubService.shared
    private let storageService = StorageService.shared
    private let authService = AuthService.shared
    private let notificationService = NotificationService.shared
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 5 * 60 // 5 minutes, matching cacheTTL

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

        // Sort categories: human first, then specific bot order, then alphabetically
        let botOrder = ["snyk-io", "renovate", "buildagencygitapitoken"]
        let sortedCategories = categories.sorted { category1, category2 in
            let a = category1.key
            let b = category2.key

            // Human always first
            if a == "human" { return true }
            if b == "human" { return false }

            // Check if categories are in the specific bot order
            let aIndex = botOrder.firstIndex(of: a) ?? Int.max
            let bIndex = botOrder.firstIndex(of: b) ?? Int.max

            // Both in ordered list - sort by their position
            if aIndex != Int.max && bIndex != Int.max {
                return aIndex < bIndex
            }

            // Only a is in ordered list - it comes first
            if aIndex != Int.max { return true }

            // Only b is in ordered list - it comes first
            if bIndex != Int.max { return false }

            // Neither in ordered list - sort alphabetically
            return a < b
        }

        return sortedCategories.map { category, requests in
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

    func loadData(forceRefresh: Bool = false) async {
        loading = true
        error = nil

        // Initialize auth if needed
        if !githubService.hasToken() {
            print("No token found, attempting to get GitHub token...")
            if let token = await authService.getGitHubToken() {
                print("Got token from auth service")
                githubService.setToken(token)
            } else {
                print("No token available - will use mock data")
            }
        } else {
            print("Token already available")
        }

        print("Loading data (forceRefresh: \(forceRefresh))...")
        do {
            let (prs, requests) = try await (
                githubService.getUserOpenPRs(forceRefresh: forceRefresh),
                githubService.getReviewRequests(forceRefresh: forceRefresh)
            )

            // Filter out dismissed PRs
            userPRs = storageService.filterDismissed(prs)
            reviewRequests = storageService.filterDismissed(requests)

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

        // Start or restart automatic refresh timer
        startRefreshTimer()
    }

    private func startRefreshTimer() {
        // Invalidate existing timer if any
        refreshTimer?.invalidate()

        // Create new timer that fires every 5 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.loadData(forceRefresh: true)
            }
        }
    }

    deinit {
        refreshTimer?.invalidate()
    }

    func dismissPR(_ prId: Int) async {
        storageService.dismissPr(prId)
        // Invalidate cache and reload
        githubService.invalidateCache()
        await loadData(forceRefresh: true)
    }
}

struct CategoryGroup {
    let category: String
    let categoryLabel: String
    let requests: [ReviewRequest]
}

