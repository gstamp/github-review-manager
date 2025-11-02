import React, { useEffect, useState } from 'react';
import type { PrSummary, ReviewRequest } from '../common/ipcChannels';

const CopyIcon = () => (
  <svg
    width="16"
    height="16"
    viewBox="0 0 16 16"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.5"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    <rect x="5" y="5" width="9" height="9" rx="1" />
    <path d="M2 11V4a2 2 0 0 1 2-2h7" />
  </svg>
);

function App() {
  const [userPrs, setUserPrs] = useState<PrSummary[]>([]);
  const [reviewRequests, setReviewRequests] = useState<ReviewRequest[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    loadData();
  }, []);

  const loadData = async (forceRefresh = false) => {
    setLoading(true);
    setError(null);
    try {
      const [prs, requests] = await Promise.all([
        window.electronAPI.getUserOpenPrs(forceRefresh),
        window.electronAPI.getReviewRequests(forceRefresh),
      ]);
      setUserPrs(prs || []);
      setReviewRequests(requests || []);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load PR data');
    } finally {
      setLoading(false);
    }
  };

  const handleDismiss = async (prId: number) => {
    try {
      await window.electronAPI.dismissPr(prId);
      // Reload data to reflect dismissed PRs
      await loadData();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to dismiss PR');
    }
  };

  const handleQuit = () => {
    window.electronAPI.quit();
  };

  const formatSlackMessage = (pr: PrSummary | ReviewRequest): string => {
    // Extract JIRA issue number from PR title (pattern: uppercase letters-dash-numbers, e.g., ATM-1312)
    const jiraPattern = /([A-Z]+-\d+)/;
    const jiraMatch = pr.title.match(jiraPattern);

    // Format: :pr: [PR#number](url) (repoName) [JIRA-XXX](jiraUrl) Title
    let message = `:pr: [PR#${pr.number}](${pr.url}) (${pr.repoName})`;

    if (jiraMatch) {
      const jiraId = jiraMatch[1];
      // Construct JIRA URL (assuming myseek.atlassian.net domain)
      const jiraUrl = `https://myseek.atlassian.net/browse/${jiraId}`;
      message += ` [${jiraId}](${jiraUrl})`;
    }

    message += ` ${pr.title}`;

    return message;
  };

  const copyToClipboard = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
    } catch (err) {
      // Fallback for older browsers or if clipboard API fails
      const textArea = document.createElement('textarea');
      textArea.value = text;
      textArea.style.position = 'fixed';
      textArea.style.opacity = '0';
      document.body.appendChild(textArea);
      textArea.select();
      document.execCommand('copy');
      document.body.removeChild(textArea);
    }
  };

  const handleCopy = async (pr: PrSummary | ReviewRequest) => {
    const message = formatSlackMessage(pr);
    await copyToClipboard(message);
  };

  const handleCopyAll = async (prs: (PrSummary | ReviewRequest)[]) => {
    const messages = prs.map((pr) => formatSlackMessage(pr));
    const allMessages = messages.join('\n');
    await copyToClipboard(allMessages);
  };

  return (
    <div className="app">
      <header className="app-header">
        <h1>GitHub PR Reviews</h1>
        <div className="header-actions">
          <button onClick={() => loadData(true)} disabled={loading}>
            Refresh
          </button>
          <button onClick={handleQuit} className="quit-btn">
            Quit
          </button>
        </div>
      </header>
      <main className="app-main">
        {loading && <div className="loading">Loading...</div>}
        {error && <div className="error">Error: {error}</div>}
        {!loading && !error && (
          <>
            <section className="section">
              <div className="section-header">
                <h2>My Open PRs</h2>
                {userPrs.length > 0 && (
                  <button
                    className="copy-all-btn"
                    onClick={() => handleCopyAll(userPrs)}
                    title="Copy all PRs"
                  >
                    <CopyIcon />
                  </button>
                )}
              </div>
              {userPrs.length === 0 ? (
                <div className="empty-state">
                  <p>No open PRs found</p>
                </div>
              ) : (
                <div className="pr-list">
                  {userPrs.map((pr) => (
                    <div key={pr.id} className="pr-item">
                      <div className="pr-header">
                        <h3>
                          <a href={pr.url} target="_blank" rel="noopener noreferrer">
                            {pr.title}
                          </a>
                        </h3>
                        <div className="pr-actions">
                          <button
                            className="copy-btn"
                            onClick={() => handleCopy(pr)}
                            title="Copy Slack link"
                          >
                            <CopyIcon />
                          </button>
                          <button
                            className="dismiss-btn"
                            onClick={() => handleDismiss(pr.id)}
                            title="Dismiss"
                          >
                            ×
                          </button>
                        </div>
                      </div>
                              <div className="pr-meta">
                                <span className="repo">
                                  {pr.repoOwner}/{pr.repoName}#{pr.number}
                                </span>
                                <span className={`status ${pr.state}`}>{pr.state}</span>
                                <span className={`review-status ${pr.reviewStatus}`}>
                                  {pr.reviewStatus}
                                </span>
                                {pr.statusState && (
                                  <span className={`status-check status-check-${pr.statusState}`}>
                                    {pr.statusState}
                                  </span>
                                )}
                                {pr.daysSinceReady !== null && (
                                  <span className="days-info">
                                    Ready for {pr.daysSinceReady.toFixed(1)} days
                                  </span>
                                )}
                              </div>
                    </div>
                  ))}
                </div>
              )}
            </section>

            <section className="section">
              <h2>Review Requests</h2>
              {reviewRequests.length === 0 ? (
                <div className="empty-state">
                  <p>No review requests found</p>
                </div>
              ) : (
                <>
                  {(() => {
                    // Group reviews by category
                    const categories = new Map<string, ReviewRequest[]>();
                    reviewRequests.forEach((request) => {
                      const category = request.reviewCategory;
                      if (!categories.has(category)) {
                        categories.set(category, []);
                      }
                      categories.get(category)!.push(request);
                    });

                    // Sort categories: human first, then specific bot order, then alphabetically
                    const botOrder = ['snyk-io', 'renovate', 'buildagencygitapitoken'];
                    const sortedCategories = Array.from(categories.entries()).sort(([a], [b]) => {
                      // Human always first
                      if (a === 'human') return -1;
                      if (b === 'human') return 1;

                      // Check if categories are in the specific bot order
                      const aIndex = botOrder.indexOf(a);
                      const bIndex = botOrder.indexOf(b);

                      // Both in ordered list - sort by their position
                      if (aIndex !== -1 && bIndex !== -1) {
                        return aIndex - bIndex;
                      }

                      // Only a is in ordered list - it comes first
                      if (aIndex !== -1) return -1;

                      // Only b is in ordered list - it comes first
                      if (bIndex !== -1) return 1;

                      // Neither in ordered list - sort alphabetically
                      return a.localeCompare(b);
                    });

                    return sortedCategories.map(([category, categoryRequests]) => {
                      // Format category label
                      const categoryLabel =
                        category === 'human'
                          ? 'From Humans'
                          : category === 'buildagencygitapitoken'
                          ? 'Promotions'
                          : category === 'snyk-io'
                          ? 'Snyk-io'
                          : category === 'renovate'
                          ? 'Renovate'
                          : category.charAt(0).toUpperCase() + category.slice(1);

                      return (
                        <div key={category} className="category-group">
                          <div className="category-header">
                            <h3 className="category-title">{categoryLabel}</h3>
                            {categoryRequests.length > 0 && (
                              <button
                                className="copy-all-btn"
                                onClick={() => handleCopyAll(categoryRequests)}
                                title="Copy all PRs in this category"
                              >
                                <CopyIcon />
                              </button>
                            )}
                          </div>
                          <div className="pr-list">
                            {categoryRequests.map((request) => (
                              <div key={request.id} className="pr-item">
                                <div className="pr-header">
                                  <h4>
                                    <a
                                      href={request.url}
                                      target="_blank"
                                      rel="noopener noreferrer"
                                    >
                                      {request.title}
                                    </a>
                                  </h4>
                                  <div className="pr-actions">
                                    <button
                                      className="copy-btn"
                                      onClick={() => handleCopy(request)}
                                      title="Copy Slack link"
                                    >
                                      <CopyIcon />
                                    </button>
                                    <button
                                      className="dismiss-btn"
                                      onClick={() => handleDismiss(request.id)}
                                      title="Dismiss"
                                    >
                                      ×
                                    </button>
                                  </div>
                                </div>
                                <div className="pr-meta">
                                  <span className="repo">
                                    {request.repoOwner}/{request.repoName}#{request.number}
                                  </span>
                                  <span className="author">by {request.author}</span>
                                  <span className={`status ${request.state}`}>{request.state}</span>
                                  <span className={`review-status ${request.reviewStatus}`}>
                                    {request.reviewStatus === 'pending' ? 'Waiting' : request.reviewStatus}
                                  </span>
                                  {request.statusState && (
                                    <span className={`status-check status-check-${request.statusState}`}>
                                      {request.statusState}
                                    </span>
                                  )}
                                  {request.daysWaiting !== null && (
                                    <span className="days-info waiting">
                                      Waiting {request.daysWaiting.toFixed(1)} days
                                    </span>
                                  )}
                                </div>
                              </div>
                            ))}
                          </div>
                        </div>
                      );
                    });
                  })()}
                </>
              )}
            </section>
          </>
        )}
      </main>
    </div>
  );
}

export default App;

