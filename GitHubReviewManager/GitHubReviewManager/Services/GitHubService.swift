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

    private init() {}

    func setToken(_ token: String?) {
        self.token = token
        self.cachedUsername = nil
        self.usernameTask = nil
    }

    func hasToken() -> Bool {
        return token != nil
    }

    private func getUsername() async throws -> String {
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
            let username = try await getUsername()

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
                    var reviewStatus: ReviewStatus = .pending
                    if let latestReview = node.reviews.nodes.last {
                        switch latestReview.state {
                        case "APPROVED":
                            reviewStatus = .approved
                        case "CHANGES_REQUESTED":
                            reviewStatus = .changesRequested
                        case "COMMENTED":
                            reviewStatus = .commented
                        default:
                            reviewStatus = .pending
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
                        statusState: statusState
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
            let username = try await getUsername()

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
                  }
                }
              }
            }
            """

            let variables: [String: Any] = [
                "searchQuery": "is:open is:pr review-requested:\(username) archived:false",
                "first": 100
            ]

            let response: GraphQLResponse<SearchQuery<ReviewRequestNode>> = try await executeGraphQL(
                query: query,
                variables: variables
            )

            // Process all nodes - don't filter, the search query already ensures user is requested
            let reviewRequests = response.data.search.nodes.map { node in
                // Determine review status
                var reviewStatus: ReviewStatus = .pending
                if let latestReview = node.reviews.nodes.last {
                    switch latestReview.state {
                    case "APPROVED":
                        reviewStatus = .approved
                    case "CHANGES_REQUESTED":
                        reviewStatus = .changesRequested
                    case "COMMENTED":
                        reviewStatus = .commented
                    default:
                        reviewStatus = .pending
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
                // Fall back to most recent event if no exact match found, since search query guarantees user is requested
                // If no events at all, fall back to PR creation date
                let reviewRequestedAt = mostRecentEvent?.createdAt ?? sortedEvents.first?.createdAt ?? node.createdAt

                // Use actor (who requested the review) for categorization
                // If no matching event, use the most recent event's actor (even if it doesn't match username)
                // This handles cases where the event structure doesn't match perfectly
                // Fall back to PR author if no actor is available
                let requester: String? = {
                    if let matchingActor = mostRecentEvent?.actor?.login {
                        return matchingActor
                    }
                    // If no matching event, try the most recent event's actor
                    if let mostRecentActor = sortedEvents.first?.actor?.login {
                        return mostRecentActor
                    }
                    // Finally fall back to PR author
                    return node.author?.login
                }()


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
                    reviewCategory: BotCategorizer.categorizeReviewer(requester),
                    statusState: statusState
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
                print("Response preview: \(String(jsonString.prefix(500)))")
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
        let username = try await getUsername()

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

        let userPRResponse: GraphQLResponse<SearchQuery<UserOpenPRNode>> = try await executeGraphQL(
            query: userPRsQuery,
            variables: userPRVariables
        )

        // Query for review requests
        let reviewRequestVariables: [String: Any] = [
            "searchQuery": "is:open is:pr review-requested:\(username) archived:false",
            "first": 100
        ]

        let reviewRequestResponse: GraphQLResponse<SearchQuery<ReviewRequestNode>> = try await executeGraphQL(
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
        let username = try await getUsername()

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

        let response: GraphQLResponse<SearchQuery<ReviewRequestNode>> = try await executeGraphQL(
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

            // Sort timeline events to find requester for categorization
            let sortedEvents = node.timelineItems.nodes.sorted { event1, event2 in
                let date1 = ISO8601DateFormatter().date(from: event1.createdAt) ?? Date.distantPast
                let date2 = ISO8601DateFormatter().date(from: event2.createdAt) ?? Date.distantPast
                return date1 > date2
            }

            // Find the most recent review_requested event for this user
            let reviewRequestedEvents = sortedEvents.filter { event in
                guard let eventLogin = event.requestedReviewer?.login else { return false }
                return eventLogin.lowercased() == username.lowercased()
            }

            let mostRecentEvent = reviewRequestedEvents.first

            // Determine requester for categorization (same logic as getReviewRequests)
            let requester: String? = {
                if let matchingActor = mostRecentEvent?.actor?.login {
                    return matchingActor
                }
                if let mostRecentActor = sortedEvents.first?.actor?.login {
                    return mostRecentActor
                }
                return node.author?.login
            }()

            let reviewCategory = BotCategorizer.categorizeReviewer(requester)

            newReviewRequests.append(NewReviewRequest(
                prId: prId,
                prNumber: node.number,
                prTitle: node.title,
                reviewCategory: reviewCategory
            ))
        }

        return newReviewRequests
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
    let repository: Repository  // Should always be present in GraphQL response
    let reviews: Reviews
    let timelineItems: ReviewRequestTimelineItems
    let commits: Commits
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
        }
    }
}

