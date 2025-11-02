import { Octokit } from '@octokit/rest';
import type {
  PrReview,
  PrSummary,
  ReviewRequest,
} from '../../common/ipcChannels';

function categorizeReviewer(reviewer: string | null): string {
  if (!reviewer) {
    return 'unknown';
  }

  // List of known bot names (without [bot] suffix)
  const knownBots = ['renovate', 'dependabot', 'snyk', 'snyk-io', 'buildagencygitapitoken'];

  // Check if it's a known bot name (case-insensitive)
  const reviewerLower = reviewer.toLowerCase();
  for (const botName of knownBots) {
    if (reviewerLower === botName || reviewerLower === `${botName}[bot]`) {
      return botName;
    }
  }

  // Check if it ends with [bot] suffix
  if (reviewer.endsWith('[bot]')) {
    // Extract bot name from format like "botname[bot]" or "reviews: botname[bot]"
    // Handle special case for "reviews:" prefix
    if (reviewer.startsWith('reviews:')) {
      const botName = reviewer.replace('reviews:', '').trim().replace('[bot]', '').toLowerCase();
      return botName || 'unknown';
    }

    // Extract bot name from "[bot]" suffix
    const botName = reviewer.replace('[bot]', '').toLowerCase();
    return botName || 'unknown';
  }

  // If it doesn't match any bot pattern, it's a human
  return 'human';
}

export class GitHubClient {
  private octokit: Octokit | null = null;
  private cachedUsername: string | null = null;
  private usernamePromise: Promise<string> | null = null;

  constructor(token?: string) {
    if (token) {
      this.octokit = new Octokit({
        auth: token,
      });
    }
  }

  private async getUsername(): Promise<string> {
    if (this.cachedUsername) {
      return this.cachedUsername;
    }

    if (this.usernamePromise) {
      return this.usernamePromise;
    }

    if (!this.octokit) {
      throw new Error('GitHub client not initialized');
    }

    this.usernamePromise = this.octokit.users.getAuthenticated().then(({ data: user }) => {
      this.cachedUsername = user.login;
      return user.login;
    });

    return this.usernamePromise;
  }

  async getPrReviews(owner: string, repo: string): Promise<PrReview[]> {
    if (!this.octokit) {
      // Return mock data for development
      return this.getMockPrReviews();
    }

    try {
      const { data: pulls } = await this.octokit.pulls.list({
        owner,
        repo,
        state: 'open',
      });

      const reviews: PrReview[] = await Promise.all(
        pulls.map(async (pull) => {
          const { data: reviews } = await this.octokit!.pulls.listReviews({
            owner,
            repo,
            pull_number: pull.number,
          });

          let reviewStatus: PrReview['reviewStatus'] = 'pending';
          const latestReview = reviews[reviews.length - 1];
          if (latestReview) {
            if (latestReview.state === 'APPROVED') {
              reviewStatus = 'approved';
            } else if (latestReview.state === 'CHANGES_REQUESTED') {
              reviewStatus = 'changes_requested';
            } else if (latestReview.state === 'COMMENTED') {
              reviewStatus = 'commented';
            }
          }

          return {
            id: pull.id,
            number: pull.number,
            title: pull.title,
            url: pull.html_url,
            state: pull.state as 'open' | 'closed' | 'merged',
            reviewStatus,
            author: pull.user?.login || 'unknown',
            createdAt: pull.created_at,
            updatedAt: pull.updated_at,
          };
        })
      );

      return reviews;
    } catch (error) {
      throw new Error(
        `Failed to fetch PR reviews: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  async listUserOpenPrs(): Promise<PrSummary[]> {
    if (!this.octokit) {
      return this.getMockPrSummaries();
    }

    try {
      // Get current user to use in search query (cached)
      const username = await this.getUsername();

      // Use GraphQL to fetch all PRs with nested data in a single query
      const query = `
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
                reviews(last: 1) {
                  nodes {
                    state
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
      `;

      const variables = {
        searchQuery: `is:open is:pr author:${username} archived:false`,
        first: 100,
      };

      const result = await this.octokit.graphql<{
        search: {
          nodes: Array<{
            id: string;
            number: number;
            title: string;
            url: string;
            state: string;
            isDraft: boolean;
            createdAt: string;
            updatedAt: string;
            author: { login: string } | null;
            repository: { name: string; owner: { login: string } };
            reviews: { nodes: Array<{ state: string }> };
            timelineItems: {
              nodes: Array<{ createdAt: string }>;
            };
            commits: {
              nodes: Array<{
                commit: {
                  statusCheckRollup: { state: string } | null;
                };
              }>;
            };
          }>;
        };
      }>(query, variables);

      const prs: PrSummary[] = result.search.nodes
        .filter((pr) => !pr.isDraft) // Skip draft PRs
        .map((pr) => {
          // Determine review status
          let reviewStatus: PrSummary['reviewStatus'] = 'pending';
          const latestReview = pr.reviews.nodes[pr.reviews.nodes.length - 1];
          if (latestReview) {
            if (latestReview.state === 'APPROVED') {
              reviewStatus = 'approved';
            } else if (latestReview.state === 'CHANGES_REQUESTED') {
              reviewStatus = 'changes_requested';
            } else if (latestReview.state === 'COMMENTED') {
              reviewStatus = 'commented';
            }
          }

          // Find when PR became ready for review
          const readyEvent = pr.timelineItems.nodes[0];
          const readyAt = readyEvent?.createdAt || pr.createdAt;

          const daysSinceReady = (Date.now() - new Date(readyAt).getTime()) / (1000 * 60 * 60 * 24);

          // Get status state from commit status check rollup
          const statusRollup = pr.commits.nodes[0]?.commit?.statusCheckRollup;
          const statusState = statusRollup
            ? (statusRollup.state.toLowerCase() as 'success' | 'failure' | 'pending' | 'error')
            : null;

          return {
            id: parseInt(pr.id, 10),
            number: pr.number,
            title: pr.title,
            url: pr.url,
            state: pr.state.toLowerCase() as 'open' | 'closed' | 'merged',
            reviewStatus,
            author: pr.author?.login || 'unknown',
            repoOwner: pr.repository.owner.login,
            repoName: pr.repository.name,
            createdAt: pr.createdAt,
            updatedAt: pr.updatedAt,
            readyAt,
            daysSinceReady,
            statusState,
          };
        });

      return prs;
    } catch (error) {
      throw new Error(
        `Failed to fetch user open PRs: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  async listRequestedReviews(): Promise<ReviewRequest[]> {
    if (!this.octokit) {
      return this.getMockReviewRequests();
    }

    try {
      // Get current user to use in search query (cached)
      const username = await this.getUsername();

      // Use GraphQL to fetch all review requests with nested data in a single query
      const query = `
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
                reviews(last: 1) {
                  nodes {
                    state
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
      `;

      const variables = {
        searchQuery: `is:open is:pr review-requested:${username} archived:false`,
        first: 100,
      };

      const result = await this.octokit.graphql<{
        search: {
          nodes: Array<{
            id: string;
            number: number;
            title: string;
            url: string;
            state: string;
            createdAt: string;
            updatedAt: string;
            author: { login: string } | null;
            repository: { name: string; owner: { login: string } };
            reviews: { nodes: Array<{ state: string }> };
            timelineItems: {
              nodes: Array<{
                createdAt: string;
                actor: { login: string } | null;
                requestedReviewer: { login: string } | null;
              }>;
            };
            commits: {
              nodes: Array<{
                commit: {
                  statusCheckRollup: { state: string } | null;
                };
              }>;
            };
          }>;
        };
      }>(query, variables);

      const reviewRequests: ReviewRequest[] = result.search.nodes
        .map((pr) => {
          // Determine review status
          let reviewStatus: ReviewRequest['reviewStatus'] = 'pending';
          const latestReview = pr.reviews.nodes[pr.reviews.nodes.length - 1];
          if (latestReview) {
            if (latestReview.state === 'APPROVED') {
              reviewStatus = 'approved';
            } else if (latestReview.state === 'CHANGES_REQUESTED') {
              reviewStatus = 'changes_requested';
            } else if (latestReview.state === 'COMMENTED') {
              reviewStatus = 'commented';
            }
          }

          // Find the most recent review_requested event for this user
          // Use case-insensitive comparison for username matching
          const reviewRequestedEvents = pr.timelineItems.nodes
            .filter((event) => {
              const eventLogin = event.requestedReviewer?.login;
              return eventLogin && eventLogin.toLowerCase() === username.toLowerCase();
            })
            .sort(
              (a, b) =>
                new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime()
            );

          const mostRecentEvent = reviewRequestedEvents[0] || null;
          // If no matching events found but PR was returned by search, assume user is requested
          // Use username as fallback since search query ensures user is requested
          const requestedReviewer = mostRecentEvent?.requestedReviewer?.login || username;
          const reviewRequestedAt = mostRecentEvent?.createdAt || null;

          // Use actor (who requested the review) for categorization, not requestedReviewer (who was requested)
          // Fall back to PR author if actor is unavailable (typical case for human PR authors)
          const requester = mostRecentEvent?.actor?.login || pr.author?.login || null;

          const daysWaiting = reviewRequestedAt
            ? (Date.now() - new Date(reviewRequestedAt).getTime()) /
              (1000 * 60 * 60 * 24)
            : null;

          // Get status state from commit status check rollup
          const statusRollup = pr.commits.nodes[0]?.commit?.statusCheckRollup;
          const statusState = statusRollup
            ? (statusRollup.state.toLowerCase() as 'success' | 'failure' | 'pending' | 'error')
            : null;

          return {
            id: parseInt(pr.id, 10),
            number: pr.number,
            title: pr.title,
            url: pr.url,
            state: pr.state.toLowerCase() as 'open' | 'closed' | 'merged',
            reviewStatus,
            author: pr.author?.login || 'unknown',
            repoOwner: pr.repository.owner.login,
            repoName: pr.repository.name,
            createdAt: pr.createdAt,
            updatedAt: pr.updatedAt,
            reviewRequestedAt,
            daysWaiting,
            requestedReviewer,
            reviewCategory: categorizeReviewer(requester),
            statusState,
          };
        });
        // No need to filter - if PR was returned by search, user is requested
        // Even if events don't match, we've set requestedReviewer to username as fallback

      return reviewRequests;
    } catch (error) {
      throw new Error(
        `Failed to fetch review requests: ${error instanceof Error ? error.message : 'Unknown error'}`
      );
    }
  }

  private getMockPrReviews(): PrReview[] {
    return [
      {
        id: 1,
        number: 123,
        title: 'Add new feature for PR reviews',
        url: 'https://github.com/owner/repo/pull/123',
        state: 'open',
        reviewStatus: 'pending',
        author: 'developer1',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      {
        id: 2,
        number: 124,
        title: 'Fix bug in token handling',
        url: 'https://github.com/owner/repo/pull/124',
        state: 'open',
        reviewStatus: 'changes_requested',
        author: 'developer2',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
      {
        id: 3,
        number: 125,
        title: 'Update documentation',
        url: 'https://github.com/owner/repo/pull/125',
        state: 'open',
        reviewStatus: 'approved',
        author: 'developer3',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      },
    ];
  }

  private getMockPrSummaries(): PrSummary[] {
    const now = new Date();
    const threeDaysAgo = new Date(now.getTime() - 3 * 24 * 60 * 60 * 1000);
    const fiveDaysAgo = new Date(now.getTime() - 5 * 24 * 60 * 60 * 1000);

    return [
      {
        id: 1,
        number: 123,
        title: 'Add new feature for PR reviews',
        url: 'https://github.com/owner/repo/pull/123',
        state: 'open',
        reviewStatus: 'pending',
        author: 'developer1',
        repoOwner: 'owner',
        repoName: 'repo',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        readyAt: threeDaysAgo.toISOString(),
        daysSinceReady: 3,
        statusState: 'success',
      },
      {
        id: 2,
        number: 124,
        title: 'Fix bug in token handling',
        url: 'https://github.com/owner/repo/pull/124',
        state: 'open',
        reviewStatus: 'changes_requested',
        author: 'developer2',
        repoOwner: 'owner',
        repoName: 'repo',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        readyAt: fiveDaysAgo.toISOString(),
        daysSinceReady: 5,
        statusState: 'failure',
      },
    ];
  }

  private getMockReviewRequests(): ReviewRequest[] {
    const now = new Date();
    const twoDaysAgo = new Date(now.getTime() - 2 * 24 * 60 * 60 * 1000);
    const sevenDaysAgo = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);

    return [
      {
        id: 4,
        number: 126,
        title: 'Refactor authentication module',
        url: 'https://github.com/owner/repo/pull/126',
        state: 'open',
        reviewStatus: 'pending',
        author: 'developer4',
        repoOwner: 'owner',
        repoName: 'repo',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reviewRequestedAt: twoDaysAgo.toISOString(),
        daysWaiting: 2,
        requestedReviewer: 'johnsmith',
        reviewCategory: 'human',
        statusState: 'success',
      },
      {
        id: 5,
        number: 127,
        title: 'Update dependencies',
        url: 'https://github.com/owner/repo/pull/127',
        state: 'open',
        reviewStatus: 'pending',
        author: 'developer5',
        repoOwner: 'owner',
        repoName: 'repo',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        reviewRequestedAt: sevenDaysAgo.toISOString(),
        daysWaiting: 7,
        requestedReviewer: 'renovate[bot]',
        reviewCategory: 'renovate',
        statusState: 'pending',
      },
    ];
  }
}

