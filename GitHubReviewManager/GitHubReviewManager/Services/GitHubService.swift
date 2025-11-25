import Foundation

class GitHubService {
    static let shared = GitHubService()

    private var token: String?
    private var cachedUsername: String?
    private var usernameTask: Task<String, Error>?

    private let graphQLURL = URL(string: "https://api.github.com/graphql")!
    private let cacheTTL: TimeInterval = 5 * 60 // 5 minutes

    private var cachedUserPRs: (data: [PRSummary], timestamp: Date)?
    private var cachedReviewRequests: (data: [ReviewRequest], timestamp: Date)?
    private var cachedMergeMethods: [String: String] = [:] // Cache merge method per "owner/repo"
    private var cachedMergeQueueRequired: [String: Bool] = [:] // Cache merge queue requirement per "owner/repo/branch"

    private init() {}

    func setToken(_ token: String?) {
        self.token = token
        self.cachedUsername = nil
        self.usernameTask = nil
    }

    func hasToken() -> Bool {
        return token != nil
    }

    func getUsername() async throws -> String {
        return try await getUsernameInternal()
    }

    private func getUsernameInternal() async throws -> String {
        if let cached = cachedUsername {
            return cached
        }

        if let existingTask = usernameTask {
            return try await existingTask.value
        }

        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        let task = Task<String, Error> {
            let query = """
            query {
              viewer {
                login
              }
            }
            """

            let response: GraphQLResponse<UsernameQuery> = try await executeGraphQL(query: query)
            let username = response.data.viewer.login
            self.cachedUsername = username
            return username
        }

        usernameTask = task
        let username = try await task.value
        return username
    }

    func getUserOpenPRs(forceRefresh: Bool = false) async throws -> [PRSummary] {
        // Return cached data if fresh and not forcing refresh
        if !forceRefresh, let cached = cachedUserPRs {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTTL {
                print("Using cached user PRs (\(cached.data.count) PRs, age: \(Int(age))s)")
                return cached.data
            }
            print("Cache expired, fetching fresh user PRs")
        } else if !forceRefresh {
            print("No cache, fetching user PRs")
        } else {
            print("Force refresh requested, fetching user PRs")
        }

        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        do {
            let username = try await getUsernameInternal()

            let query = """
            query($searchQuery: String!, $first: Int!) {
              search(query: $searchQuery, type: ISSUE, first: $first) {
                nodes {
                  ... on PullRequest {
                    id
                    number
                    title
                    url
                    state
                    isDraft
                    createdAt
                    updatedAt
                    author {
                      login
                    }
                    repository {
                      name
                      owner {
                        login
                      }
                    }
                    reviews(last: 100) {
                      nodes {
                        id
                        state
                        author {
                          login
                        }
                        createdAt
                      }
                    }
                    timelineItems(itemTypes: READY_FOR_REVIEW_EVENT, last: 1) {
                      nodes {
                        ... on ReadyForReviewEvent {
                          createdAt
                        }
                      }
                    }
                    commits(last: 1) {
                      nodes {
                        commit {
                          statusCheckRollup {
                            state
                          }
                        }
                      }
                    }
                    mergeable
                    mergeQueueEntry {
                      state
                      position
                    }
                  }
                }
              }
            }
            """

            let variables: [String: Any] = [
                "searchQuery": "is:open is:pr author:\(username) archived:false",
                "first": 100
            ]

            let response: GraphQLResponse<SearchQuery<UserOpenPRNode>> = try await executeGraphQL(
                query: query,
                variables: variables
            )

            let prs = response.data.search.nodes
                .filter { !$0.isDraft } // Skip draft PRs
                .map { node in
                    // Determine review status
                    var reviewStatus: ReviewStatus = .waiting
                    if let latestReview = node.reviews.nodes.last {
                        switch latestReview.state {
                        case "APPROVED":
                            reviewStatus = .approved
                        case "CHANGES_REQUESTED":
                            reviewStatus = .changesRequested
                        case "COMMENTED":
                            reviewStatus = .commented
                        default:
                            reviewStatus = .waiting
                        }
                    }

                    // Find when PR became ready for review
                    let readyAt = node.timelineItems.nodes.first?.createdAt ?? node.createdAt

                    let daysSinceReady: Double = {
                        let formatter = ISO8601DateFormatter()
                        guard let date = formatter.date(from: readyAt) else {
                            return 0
                        }
                        return (Date().timeIntervalSince1970 - date.timeIntervalSince1970) / (60 * 60 * 24)
                    }()

                    // Get status state from commit status check rollup
                    let statusState: StatusState? = {
                        guard let state = node.commits.nodes.first?.commit.statusCheckRollup?.state else {
                            return nil
                        }
                        return StatusState(rawValue: state.lowercased())
                    }()

                    // GitHub GraphQL IDs are base64-encoded strings (e.g., "PR_kwDO...")
                    // Create a stable hash for use as an Int ID
                    let prId = node.id.stableHash()

                    let mergeQueueEntry: MergeQueueEntryInfo? = {
                        guard let entry = node.mergeQueueEntry,
                              let state = MergeQueueState(rawValue: entry.state) else {
                            return nil
                        }
                        return MergeQueueEntryInfo(state: state, position: entry.position)
                    }()

                    return PRSummary(
                        id: prId,
                        number: node.number,
                        title: node.title,
                        url: node.url,
                        state: PRState(rawValue: node.state.lowercased()) ?? .open,
                        reviewStatus: reviewStatus,
                        author: node.author?.login ?? "unknown",
                        repoOwner: node.repository.owner.login,
                        repoName: node.repository.name,
                        createdAt: node.createdAt,
                        updatedAt: node.updatedAt,
                        readyAt: readyAt,
                        daysSinceReady: daysSinceReady,
                        statusState: statusState,
                        mergeable: node.mergeable == .mergeable,
                        graphQLId: node.id,
                        mergeQueueEntry: mergeQueueEntry
                    )
                }

            cachedUserPRs = (prs, Date())
            print("Found \(prs.count) user open PRs")
            return prs
        } catch let error {
            print("Error fetching user PRs: \(error)")
            // Return cached data on error if available
            if let cached = cachedUserPRs {
                print("Returning cached data: \(cached.data.count) PRs")
                return cached.data
            }
            throw error
        }
    }

    func getReviewRequests(forceRefresh: Bool = false) async throws -> [ReviewRequest] {
        // Return cached data if fresh and not forcing refresh
        if !forceRefresh, let cached = cachedReviewRequests {
            let age = Date().timeIntervalSince(cached.timestamp)
            if age < cacheTTL {
                print("Using cached review requests (\(cached.data.count) requests, age: \(Int(age))s)")
                return cached.data
            }
            print("Cache expired, fetching fresh review requests")
        } else if !forceRefresh {
            print("No cache, fetching review requests")
        } else {
            print("Force refresh requested, fetching review requests")
        }

        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        do {
            let username = try await getUsernameInternal()

            let query = """
            query($searchQuery: String!, $first: Int!) {
            search(query: $searchQuery, type: ISSUE, first: $first) {
              nodes {
                ... on PullRequest {
                  id
                  number
                  title
                  url
                  state
                  createdAt
                  updatedAt
                  author {
                    login
                  }
                  repository {
                    name
                    owner {
                      login
                    }
                  }
                  reviews(last: 100) {
                    nodes {
                      id
                      state
                      author {
                        login
                      }
                      createdAt
                    }
                  }
                  timelineItems(itemTypes: REVIEW_REQUESTED_EVENT, last: 50) {
                      nodes {
                        ... on ReviewRequestedEvent {
                          createdAt
                          actor {
                            ... on User {
                              login
                            }
                            ... on Bot {
                              login
                            }
                          }
                          requestedReviewer {
                            ... on User {
                              login
                            }
                            ... on Bot {
                              login
                            }
                          }
                        }
                      }
                    }
                    commits(last: 1) {
                      nodes {
                        commit {
                          statusCheckRollup {
                            state
                          }
                        }
                      }
                    }
                    mergeable
                    mergeQueueEntry {
                      state
                      position
                    }
                  }
                }
              }
            }
            """

            // Fetch PRs currently requested for review
            let requestedVariables: [String: Any] = [
                "searchQuery": "is:open is:pr review-requested:\(username) archived:false",
                "first": 100
            ]

            let requestedResponse: GraphQLResponse<SearchQuery<ReviewRequestNode>> = try await executeGraphQL(
                query: query,
                variables: requestedVariables
            )

            // Fetch PRs reviewed by user (but not authored by them) to include approved PRs waiting to merge
            let reviewedVariables: [String: Any] = [
                "searchQuery": "is:open is:pr reviewed-by:\(username) -author:\(username) archived:false",
                "first": 100
            ]

            let reviewedResponse: GraphQLResponse<SearchQuery<ReviewRequestNode>> = try await executeGraphQL(
                query: query,
                variables: reviewedVariables
            )

            // Combine both sets and deduplicate by PR ID
            var prMap: [String: ReviewRequestNode] = [:]
            for node in requestedResponse.data.search.nodes {
                prMap[node.id] = node
            }
            for node in reviewedResponse.data.search.nodes {
                // Only add if not already present (prefer requested over reviewed)
                if prMap[node.id] == nil {
                    prMap[node.id] = node
                }
            }

            // Process all nodes
            let reviewRequests = prMap.values.map { node in
                // Determine review status
                var reviewStatus: ReviewStatus = .waiting
                if let latestReview = node.reviews.nodes.last {
                    switch latestReview.state {
                    case "APPROVED":
                        reviewStatus = .approved
                    case "CHANGES_REQUESTED":
                        reviewStatus = .changesRequested
                    case "COMMENTED":
                        reviewStatus = .commented
                    default:
                        reviewStatus = .waiting
                    }
                }

                // Sort all timeline events by date (most recent first)
                let sortedEvents = node.timelineItems.nodes.sorted { event1, event2 in
                    let date1 = ISO8601DateFormatter().date(from: event1.createdAt) ?? Date.distantPast
                    let date2 = ISO8601DateFormatter().date(from: event2.createdAt) ?? Date.distantPast
                    return date1 > date2
                }

                // Find the most recent review_requested event for this user
                let reviewRequestedEvents = sortedEvents.filter { event in
                    // requestedReviewer can be nil (team), or have login (user/bot)
                    guard let eventLogin = event.requestedReviewer?.login else { return false }
                    return eventLogin.lowercased() == username.lowercased()
                }

                let mostRecentEvent = reviewRequestedEvents.first
                // If no matching events found but PR was returned by search, assume user is requested
                // Use username as fallback since search query ensures user is requested
                let requestedReviewer = mostRecentEvent?.requestedReviewer?.login ?? username

                // Find user's review date as fallback for PRs from reviewed-by query
                let userReviewDate: String? = {
                    // Find the user's review in the reviews list
                    for review in node.reviews.nodes {
                        guard let authorLogin = review.author?.login else {
                            continue
                        }
                        if authorLogin.lowercased() == username.lowercased() {
                            return review.createdAt
                        }
                    }
                    return nil
                }()

                // Fall back to most recent event if no exact match found, then user's review date, then PR creation date
                let reviewRequestedAt = mostRecentEvent?.createdAt ?? sortedEvents.first?.createdAt ?? userReviewDate ?? node.createdAt

                let daysWaiting: Double? = {
                    let formatter = ISO8601DateFormatter()
                    guard let date = formatter.date(from: reviewRequestedAt) else {
                        return nil
                    }
                    return (Date().timeIntervalSince1970 - date.timeIntervalSince1970) / (60 * 60 * 24)
                }()

                // Get status state from commit status check rollup
                let statusState: StatusState? = {
                    guard let state = node.commits.nodes.first?.commit.statusCheckRollup?.state else {
                        return nil
                    }
                    return StatusState(rawValue: state.lowercased())
                }()

                // GitHub GraphQL IDs are base64-encoded strings (e.g., "PR_kwDO...")
                // Create a stable hash for use as an Int ID
                let prId = node.id.stableHash()

                let mergeQueueEntry: MergeQueueEntryInfo? = {
                    guard let entry = node.mergeQueueEntry,
                          let state = MergeQueueState(rawValue: entry.state) else {
                        return nil
                    }
                    return MergeQueueEntryInfo(state: state, position: entry.position)
                }()

                return ReviewRequest(
                    id: prId,
                    number: node.number,
                    title: node.title,
                    url: node.url,
                    state: PRState(rawValue: node.state.lowercased()) ?? .open,
                    reviewStatus: reviewStatus,
                    author: node.author?.login ?? "unknown",
                    repoOwner: node.repository.owner.login,
                    repoName: node.repository.name,
                    createdAt: node.createdAt,
                    updatedAt: node.updatedAt,
                    reviewRequestedAt: reviewRequestedAt,
                    daysWaiting: daysWaiting,
                    requestedReviewer: requestedReviewer,
                    reviewCategory: BotCategorizer.categorizeReviewer(node.author?.login),
                    statusState: statusState,
                    graphQLId: node.id,
                    mergeable: node.mergeable == .mergeable,
                    mergeQueueEntry: mergeQueueEntry
                )
            }

            cachedReviewRequests = (reviewRequests, Date())
            return reviewRequests
        } catch let error {
            print("Error fetching review requests: \(error)")
            // Return cached data on error if available
            if let cached = cachedReviewRequests {
                print("Returning cached data: \(cached.data.count) requests")
                return cached.data
            }
            throw error
        }
    }

    // MARK: - GraphQL Execution

    private func executeGraphQL<T: Decodable>(
        query: String,
        variables: [String: Any]? = nil
    ) async throws -> T {
        guard let token = token else {
            throw GitHubError.notAuthenticated
        }

        var requestBody: [String: Any] = ["query": query]
        if let variables = variables {
            requestBody["variables"] = variables
        }

        var request = URLRequest(url: graphQLURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            throw GitHubError.httpError(statusCode: httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        // GitHub GraphQL API returns camelCase, not snake_case
        // No conversion needed - Swift structs should match GraphQL field names exactly

        do {
            return try decoder.decode(T.self, from: data)
        } catch let decodeError {
            // Try to get GraphQL errors first
            if let errorResponse = try? decoder.decode(GraphQLErrorResponse.self, from: data) {
                let errorMessage = errorResponse.errors.first?.message ?? "Unknown GraphQL error"
                print("GraphQL Error: \(errorMessage)")
                throw GitHubError.graphQLError(errorMessage)
            }
            // Log decoding error for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Decoding error: \(decodeError)")
                print("Full response: \(jsonString)")
            }
            throw decodeError
        }
    }


    func invalidateCache() {
        cachedUserPRs = nil
        cachedReviewRequests = nil
    }

    // MARK: - Review Detection

    /// Detect new human reviews that haven't been seen before
    func detectNewReviews() async throws -> [NewReview] {
        guard token != nil else {
            return []
        }

        let storageService = StorageService.shared
        let seenReviewIds = storageService.loadSeenReviewIds()

        // Get username for filtering
        let username = try await getUsernameInternal()

        // Fetch full PR data with reviews
        let userPRsQuery = """
        query($searchQuery: String!, $first: Int!) {
          search(query: $searchQuery, type: ISSUE, first: $first) {
            nodes {
              ... on PullRequest {
                id
                number
                title
                url
                state
                reviews(last: 100) {
                  nodes {
                    id
                    state
                    author {
                      login
                    }
                    createdAt
                  }
                }
              }
            }
          }
        }
        """

        let reviewRequestsQuery = """
        query($searchQuery: String!, $first: Int!) {
          search(query: $searchQuery, type: ISSUE, first: $first) {
            nodes {
              ... on PullRequest {
                id
                number
                title
                url
                state
                reviews(last: 100) {
                  nodes {
                    id
                    state
                    author {
                      login
                    }
                    createdAt
                  }
                }
              }
            }
          }
        }
        """

        // Query for user PRs
        let userPRVariables: [String: Any] = [
            "searchQuery": "is:open is:pr author:\(username) archived:false",
            "first": 100
        ]

        let userPRResponse: GraphQLResponse<SearchQuery<ReviewDetectionPRNode>> = try await executeGraphQL(
            query: userPRsQuery,
            variables: userPRVariables
        )

        // Query for review requests
        let reviewRequestVariables: [String: Any] = [
            "searchQuery": "is:open is:pr review-requested:\(username) archived:false",
            "first": 100
        ]

        let reviewRequestResponse: GraphQLResponse<SearchQuery<ReviewDetectionPRNode>> = try await executeGraphQL(
            query: reviewRequestsQuery,
            variables: reviewRequestVariables
        )

        var newReviews: [NewReview] = []

        // Process user PRs
        for prNode in userPRResponse.data.search.nodes {
            for review in prNode.reviews.nodes {
                // Only process APPROVED, CHANGES_REQUESTED, COMMENTED
                guard ["APPROVED", "CHANGES_REQUESTED", "COMMENTED"].contains(review.state) else {
                    continue
                }

                // Check if review is from a human
                guard let authorLogin = review.author?.login else {
                    continue
                }

                let category = BotCategorizer.categorizeReviewer(authorLogin)
                guard category == "human" else {
                    continue
                }

                // Check if we've seen this review before
                if !seenReviewIds.contains(review.id) {
                    newReviews.append(NewReview(
                        reviewId: review.id,
                        prNumber: prNode.number,
                        prTitle: prNode.title,
                        reviewState: review.state
                    ))
                }
            }
        }

        // Process review requests
        for prNode in reviewRequestResponse.data.search.nodes {
            for review in prNode.reviews.nodes {
                // Only process APPROVED, CHANGES_REQUESTED, COMMENTED
                guard ["APPROVED", "CHANGES_REQUESTED", "COMMENTED"].contains(review.state) else {
                    continue
                }

                // Check if review is from a human
                guard let authorLogin = review.author?.login else {
                    continue
                }

                let category = BotCategorizer.categorizeReviewer(authorLogin)
                guard category == "human" else {
                    continue
                }

                // Check if we've seen this review before
                if !seenReviewIds.contains(review.id) {
                    newReviews.append(NewReview(
                        reviewId: review.id,
                        prNumber: prNode.number,
                        prTitle: prNode.title,
                        reviewState: review.state
                    ))
                }
            }
        }

        return newReviews
    }

    /// Detect new review requests that haven't been seen before
    func detectNewReviewRequests() async throws -> [NewReviewRequest] {
        guard token != nil else {
            return []
        }

        let storageService = StorageService.shared
        let seenRequestIds = storageService.loadSeenReviewRequestIds()

        // Get username for filtering
        let username = try await getUsernameInternal()

        // Use the same query as getReviewRequests to fetch review requests
        let query = """
        query($searchQuery: String!, $first: Int!) {
          search(query: $searchQuery, type: ISSUE, first: $first) {
            nodes {
              ... on PullRequest {
                id
                number
                title
                url
                state
                author {
                  login
                }
                repository {
                  name
                  owner {
                    login
                  }
                }
                timelineItems(itemTypes: REVIEW_REQUESTED_EVENT, last: 50) {
                  nodes {
                    ... on ReviewRequestedEvent {
                      createdAt
                      actor {
                        ... on User {
                          login
                        }
                        ... on Bot {
                          login
                        }
                      }
                      requestedReviewer {
                        ... on User {
                          login
                        }
                        ... on Bot {
                          login
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """

        let variables: [String: Any] = [
            "searchQuery": "is:open is:pr review-requested:\(username) archived:false",
            "first": 100
        ]

        let response: GraphQLResponse<SearchQuery<ReviewRequestDetectionNode>> = try await executeGraphQL(
            query: query,
            variables: variables
        )

        var newReviewRequests: [NewReviewRequest] = []

        for node in response.data.search.nodes {
            // Get PR ID (same hash method as in getReviewRequests)
            let prId = node.id.stableHash()

            // Skip if we've already seen this review request
            if seenRequestIds.contains(prId) {
                continue
            }

            // Categorize by PR author (not reviewer) for grouping
            let reviewCategory = BotCategorizer.categorizeReviewer(node.author?.login)

            newReviewRequests.append(NewReviewRequest(
                prId: prId,
                prNumber: node.number,
                prTitle: node.title,
                reviewCategory: reviewCategory
            ))
        }

        return newReviewRequests
    }

    // MARK: - PR Approval

    /// Approve a pull request via GraphQL mutation
    func approvePR(pullRequestId: String) async throws {
        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        let mutation = """
        mutation($pullRequestId: ID!) {
          addPullRequestReview(input: {
            pullRequestId: $pullRequestId
            event: APPROVE
            body: ""
          }) {
            pullRequestReview {
              id
              state
            }
          }
        }
        """

        let variables: [String: Any] = [
            "pullRequestId": pullRequestId
        ]

        struct ApproveResponse: Decodable {
            let addPullRequestReview: AddPullRequestReview
        }

        struct AddPullRequestReview: Decodable {
            let pullRequestReview: ReviewResponse
        }

        struct ReviewResponse: Decodable {
            let id: String
            let state: String
        }

        let response: GraphQLResponse<ApproveResponse> = try await executeGraphQL(
            query: mutation,
            variables: variables
        )

        // Check for GraphQL errors in response
        if let errors = response.errors, !errors.isEmpty {
            let errorMessages = errors.map { $0.message }.joined(separator: "; ")
            print("GraphQL errors in approve response: \(errorMessages)")
            throw GitHubError.graphQLError(errorMessages)
        }

        print("Approval successful. Review ID: \(response.data.addPullRequestReview.pullRequestReview.id), State: \(response.data.addPullRequestReview.pullRequestReview.state)")

        // Invalidate cache after approval
        invalidateCache()
    }

    // MARK: - Repository Merge Method

    /// Get the repository's default merge method (MERGE, SQUASH, or REBASE)
    /// Caches the result per repository to minimize API calls
    func getRepositoryMergeMethod(owner: String, repo: String) async throws -> String {
        let cacheKey = "\(owner)/\(repo)"

        // Return cached value if available
        if let cached = cachedMergeMethods[cacheKey] {
            return cached
        }

        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        let query = """
        query($owner: String!, $repo: String!) {
          repository(owner: $owner, name: $repo) {
            mergeCommitAllowed
            squashMergeAllowed
            rebaseMergeAllowed
          }
        }
        """

        let variables: [String: Any] = [
            "owner": owner,
            "repo": repo
        ]

        struct RepositoryMergeMethodResponse: Decodable {
            let repository: RepositoryMergeSettings
        }

        struct RepositoryMergeSettings: Decodable {
            let mergeCommitAllowed: Bool
            let squashMergeAllowed: Bool
            let rebaseMergeAllowed: Bool
        }

        let response: GraphQLResponse<RepositoryMergeMethodResponse> = try await executeGraphQL(
            query: query,
            variables: variables
        )

        // Determine merge method: MERGE > SQUASH > REBASE
        let mergeMethod: String
        if response.data.repository.mergeCommitAllowed {
            mergeMethod = "MERGE"
        } else if response.data.repository.squashMergeAllowed {
            mergeMethod = "SQUASH"
        } else if response.data.repository.rebaseMergeAllowed {
            mergeMethod = "REBASE"
        } else {
            // Fallback to MERGE if none are allowed (shouldn't happen)
            mergeMethod = "MERGE"
        }

        // Cache the result
        cachedMergeMethods[cacheKey] = mergeMethod
        return mergeMethod
    }

    // MARK: - PR Merge

    /// Get the base branch name for a pull request
    private func getPRBaseBranch(pullRequestId: String) async throws -> String {
        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        let query = """
        query($pullRequestId: ID!) {
          node(id: $pullRequestId) {
            ... on PullRequest {
              baseRefName
            }
          }
        }
        """

        let variables: [String: Any] = [
            "pullRequestId": pullRequestId
        ]

        struct BaseBranchResponse: Decodable {
            let node: PRNode?
        }

        struct PRNode: Decodable {
            let baseRefName: String
        }

        let response: GraphQLResponse<BaseBranchResponse> = try await executeGraphQL(
            query: query,
            variables: variables
        )

        guard let baseRefName = response.data.node?.baseRefName else {
            throw GitHubError.graphQLError("Could not determine base branch for PR")
        }

        return baseRefName
    }

    /// Merge a pull request using the specified merge method
    /// Automatically handles merge queue requirements
    func mergePR(pullRequestId: String, mergeMethod: String, owner: String, repo: String) async throws {
        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        // Check if merge queue is required for this repository/branch
        do {
            let baseBranch = try await getPRBaseBranch(pullRequestId: pullRequestId)
            let requiresQueue = try await requiresMergeQueue(owner: owner, repo: repo, branch: baseBranch)

            if requiresQueue {
                print("Repository requires merge queue, enqueueing PR instead of merging directly...")
                try await enqueuePR(pullRequestId: pullRequestId)
                throw GitHubError.mergeQueued
            }
        } catch let queueError {
            // If it's our mergeQueued error, rethrow it
            if case GitHubError.mergeQueued = queueError {
                throw queueError
            }
            // If checking fails, log but continue with merge attempt
            // (fallback to error-based detection)
            print("Could not check merge queue requirement, will attempt merge: \(queueError)")
        }

        // Attempt merge - wrap in do-catch to handle errors from executeGraphQL
        do {
            let mutation = """
            mutation($pullRequestId: ID!, $mergeMethod: PullRequestMergeMethod!) {
              mergePullRequest(input: {
                pullRequestId: $pullRequestId
                mergeMethod: $mergeMethod
              }) {
                pullRequest {
                  id
                  merged
                }
              }
            }
            """

            let variables: [String: Any] = [
                "pullRequestId": pullRequestId,
                "mergeMethod": mergeMethod
            ]

            struct MergeResponse: Decodable {
                let mergePullRequest: MergePullRequest
            }

            struct MergePullRequest: Decodable {
                let pullRequest: MergedPR
            }

            struct MergedPR: Decodable {
                let id: String
                let merged: Bool
            }

            let response: GraphQLResponse<MergeResponse> = try await executeGraphQL(
                query: mutation,
                variables: variables
            )

            // Check for GraphQL errors in response
            if let errors = response.errors, !errors.isEmpty {
                let errorMessages = errors.map { $0.message }.joined(separator: "; ")
                print("GraphQL errors in merge response: \(errorMessages)")
                print("Error messages (raw): \(errors.map { $0.message })")

                // Check if this is a merge queue error - if so, try enqueueing instead
                // This handles both branch protection merge queues and repository rule merge queues
                let lowercasedError = errorMessages.lowercased()
                print("Checking for merge queue error patterns in: \(lowercasedError)")

                let isMergeQueueError = lowercasedError.contains("merge queue") ||
                                        lowercasedError.contains("must be enqueued") ||
                                        lowercasedError.contains("must be made through") ||
                                        lowercasedError.contains("cannot be merged directly") ||
                                        lowercasedError.contains("pull request is in a merge queue") ||
                                        lowercasedError.contains("repository rule violations") ||
                                        (lowercasedError.contains("repository rule") && lowercasedError.contains("merge"))

                print("Is merge queue error: \(isMergeQueueError)")

                if isMergeQueueError {
                    print("Detected merge queue requirement from error: \(errorMessages)")
                    print("Attempting to enqueue PR instead of merging directly...")
                    // Try to enqueue instead of merging directly
                    do {
                        try await enqueuePR(pullRequestId: pullRequestId)
                        print("Successfully enqueued PR to merge queue")
                        // Enqueue succeeded - throw a special error that indicates success but needs different handling
                        throw GitHubError.mergeQueued
                    } catch let enqueueError {
                        print("Failed to enqueue PR: \(enqueueError)")
                        // If it's already our special queued error, rethrow it
                        if case GitHubError.mergeQueued = enqueueError {
                            throw enqueueError
                        }
                        // If enqueue also fails, throw the original merge error with context
                        throw GitHubError.graphQLError("This repository uses a merge queue. Failed to enqueue PR: \(errorMessages)")
                    }
                }

                throw GitHubError.graphQLError(errorMessages)
            }

            // Verify that the merge actually succeeded
            let merged = response.data.mergePullRequest.pullRequest.merged
            if !merged {
                let errorMessage = "Merge request completed but PR was not merged. The PR may have conflicts, failed checks, or other restrictions."
                print("Merge failed: \(errorMessage)")
                throw GitHubError.graphQLError(errorMessage)
            }

            print("Merge successful. PR ID: \(response.data.mergePullRequest.pullRequest.id)")

            // Invalidate cache after merge
            invalidateCache()
        } catch let mergeError {
            // Check if this is a merge queue error that was thrown from executeGraphQL
            if case GitHubError.graphQLError(let errorMessage) = mergeError {
                let lowercasedError = errorMessage.lowercased()
                let isMergeQueueError = lowercasedError.contains("merge queue") ||
                                        lowercasedError.contains("must be enqueued") ||
                                        lowercasedError.contains("must be made through") ||
                                        lowercasedError.contains("cannot be merged directly") ||
                                        lowercasedError.contains("pull request is in a merge queue") ||
                                        lowercasedError.contains("repository rule violations") ||
                                        (lowercasedError.contains("repository rule") && lowercasedError.contains("merge"))

                if isMergeQueueError {
                    print("Detected merge queue error from executeGraphQL: \(errorMessage)")
                    print("Attempting to enqueue PR instead...")
                    do {
                        try await enqueuePR(pullRequestId: pullRequestId)
                        print("Successfully enqueued PR to merge queue")
                        throw GitHubError.mergeQueued
                    } catch let enqueueError {
                        if case GitHubError.mergeQueued = enqueueError {
                            throw enqueueError
                        }
                        throw GitHubError.graphQLError("This repository uses a merge queue. Failed to enqueue PR: \(errorMessage)")
                    }
                }
            }
            // Re-throw the original error if not a merge queue error
            throw mergeError
        }
    }

    // MARK: - PR Merge Queue

    /// Check if a repository branch requires merge queue
    /// Returns true if merge queue is required, false otherwise
    func requiresMergeQueue(owner: String, repo: String, branch: String) async throws -> Bool {
        let cacheKey = "\(owner)/\(repo)/\(branch)"

        // Return cached value if available
        if let cached = cachedMergeQueueRequired[cacheKey] {
            return cached
        }

        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        let query = """
        query($owner: String!, $repo: String!, $branch: String!) {
          repository(owner: $owner, name: $repo) {
            mergeQueue(branch: $branch) {
              id
            }
            defaultBranchRef {
              name
            }
          }
        }
        """

        let variables: [String: Any] = [
            "owner": owner,
            "repo": repo,
            "branch": branch
        ]

        struct MergeQueueCheckResponse: Decodable {
            let repository: MergeQueueRepository?
        }

        struct MergeQueueRepository: Decodable {
            let mergeQueue: MergeQueue?
            let defaultBranchRef: DefaultBranchRef?
        }

        struct MergeQueue: Decodable {
            let id: String
        }

        struct DefaultBranchRef: Decodable {
            let name: String
        }

        do {
            let response: GraphQLResponse<MergeQueueCheckResponse> = try await executeGraphQL(
                query: query,
                variables: variables
            )

            // If mergeQueue exists, it means merge queue is configured for this branch
            let requiresQueue = response.data.repository?.mergeQueue != nil

            // Cache the result
            cachedMergeQueueRequired[cacheKey] = requiresQueue
            return requiresQueue
        } catch {
            // If query fails (e.g., branch doesn't exist or no access), assume no merge queue
            // This is a fallback - we'll still try merge and handle errors if needed
            print("Could not check merge queue requirement: \(error)")
            cachedMergeQueueRequired[cacheKey] = false
            return false
        }
    }

    /// Enqueue a pull request to the merge queue
    func enqueuePR(pullRequestId: String) async throws {
        guard token != nil else {
            throw GitHubError.notAuthenticated
        }

        let mutation = """
        mutation($pullRequestId: ID!) {
          enqueuePullRequest(input: {
            pullRequestId: $pullRequestId
          }) {
            mergeQueueEntry {
              id
              position
            }
          }
        }
        """

        let variables: [String: Any] = [
            "pullRequestId": pullRequestId
        ]

        struct EnqueueResponse: Decodable {
            let enqueuePullRequest: EnqueuePullRequest?
        }

        struct EnqueuePullRequest: Decodable {
            let mergeQueueEntry: MergeQueueEntry?
        }

        struct MergeQueueEntry: Decodable {
            let id: String
            let position: Int
        }

        let response: GraphQLResponse<EnqueueResponse> = try await executeGraphQL(
            query: mutation,
            variables: variables
        )

        // Check for GraphQL errors in response
        if let errors = response.errors, !errors.isEmpty {
            let errorMessages = errors.map { $0.message }.joined(separator: "; ")
            print("GraphQL errors in enqueue response: \(errorMessages)")
            throw GitHubError.graphQLError(errorMessages)
        }

        // Check if enqueue was successful
        guard let enqueueResult = response.data.enqueuePullRequest else {
            throw GitHubError.graphQLError("Failed to enqueue PR to merge queue")
        }

        if let entry = enqueueResult.mergeQueueEntry {
            print("PR enqueued successfully. Queue position: \(entry.position)")
        } else {
            print("PR enqueued successfully (no position info available)")
        }

        // Invalidate cache after enqueue
        invalidateCache()
    }
}

// MARK: - Review Detection Types

struct NewReview {
    let reviewId: String
    let prNumber: Int
    let prTitle: String
    let reviewState: String
}

struct NewReviewRequest {
    let prId: Int
    let prNumber: Int
    let prTitle: String
    let reviewCategory: String
}

struct ReviewDetectionPRNode: Decodable {
    let id: String
    let number: Int
    let title: String
    let reviews: Reviews
}

struct ReviewRequestDetectionNode: Decodable {
    let id: String
    let number: Int
    let title: String
    let author: Author?
}

// MARK: - GraphQL Response Types

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
}

struct GraphQLErrorResponse: Decodable {
    let errors: [GraphQLError]
}

struct UsernameQuery: Decodable {
    let viewer: Viewer
}

struct Viewer: Decodable {
    let login: String
}

struct SearchQuery<Node: Decodable>: Decodable {
    let search: Search<Node>
}

struct Search<Node: Decodable>: Decodable {
    let nodes: [Node]
}

struct UserOpenPRNode: Decodable {
    let id: String
    let number: Int
    let title: String
    let url: String
    let state: String
    let isDraft: Bool
    let createdAt: String
    let updatedAt: String
    let author: Author?
    let repository: Repository
    let reviews: Reviews
    let timelineItems: TimelineItems
    let commits: Commits
    let mergeable: MergeableState?
    let mergeQueueEntry: MergeQueueEntryNode?
}

enum MergeableState: String, Decodable {
    case mergeable = "MERGEABLE"
    case conflicting = "CONFLICTING"
    case unknown = "UNKNOWN"
}

struct ReviewRequestNode: Decodable {
    let id: String
    let number: Int
    let title: String
    let url: String
    let state: String
    let createdAt: String
    let updatedAt: String
    let author: Author?
    let repository: Repository
    let reviews: Reviews
    let timelineItems: ReviewRequestTimelineItems
    let commits: Commits
    let mergeable: MergeableState?
    let mergeQueueEntry: MergeQueueEntryNode?
}

struct MergeQueueEntryNode: Decodable {
    let state: String
    let position: Int?
}

struct Author: Decodable {
    let login: String
}

struct Repository: Decodable {
    let name: String
    let owner: Owner
}

struct Owner: Decodable {
    let login: String
}

struct Reviews: Decodable {
    let nodes: [ReviewNode]
}

struct ReviewNode: Decodable {
    let id: String
    let state: String
    let author: ReviewAuthor?
    let createdAt: String
}

struct ReviewAuthor: Decodable {
    let login: String
}

struct TimelineItems: Decodable {
    let nodes: [TimelineItem]
}

struct TimelineItem: Decodable {
    let createdAt: String
}

struct ReviewRequestTimelineItems: Decodable {
    let nodes: [ReviewRequestEvent]
}

struct ReviewRequestEvent: Decodable {
    let createdAt: String
    let actor: Actor?
    let requestedReviewer: RequestedReviewer?
}

// RequestedReviewer can be User, Bot, or Team (Team doesn't have login)
struct RequestedReviewer: Decodable {
    let login: String?

    // Handle different types - User and Bot have login, Team doesn't
    enum CodingKeys: String, CodingKey {
        case login
        case name  // Teams have name instead of login
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Try login first (User/Bot), fall back to name (Team)
        login = try? container.decode(String.self, forKey: .login)
        if login == nil {
            // Teams use name, but we'll use it as login for our purposes
            // Check if team name exists, but leave login as nil
            // since we can't categorize teams properly
            _ = try? container.decode(String.self, forKey: .name)
        }
    }
}

struct Actor: Decodable {
    let login: String
}

struct Commits: Decodable {
    let nodes: [CommitNode]
}

struct CommitNode: Decodable {
    let commit: Commit
}

struct Commit: Decodable {
    let statusCheckRollup: StatusCheckRollup?
}

struct StatusCheckRollup: Decodable {
    let state: String
}

// MARK: - Errors

enum GitHubError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case httpError(statusCode: Int)
    case graphQLError(String)
    case mergeQueued

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "GitHub client not authenticated"
        case .invalidResponse:
            return "Invalid response from GitHub API"
        case .httpError(let statusCode):
            return "HTTP error: \(statusCode)"
        case .graphQLError(let message):
            return "GraphQL error: \(message)"
        case .mergeQueued:
            return "PR has been added to the merge queue"
        }
    }
}

