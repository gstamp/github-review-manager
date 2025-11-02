export interface IpcChannels {
  'github:getPrReviews': {
    request: [owner: string, repo: string];
    response: PrReview[];
  };
  'github:getUserOpenPrs': {
    request: [forceRefresh?: boolean];
    response: PrSummary[];
  };
  'github:getReviewRequests': {
    request: [forceRefresh?: boolean];
    response: ReviewRequest[];
  };
  'github:dismissPr': {
    request: [prId: number];
    response: void;
  };
}

export interface PrReview {
  id: number;
  number: number;
  title: string;
  url: string;
  state: 'open' | 'closed' | 'merged';
  reviewStatus: 'pending' | 'approved' | 'changes_requested' | 'commented';
  author: string;
  createdAt: string;
  updatedAt: string;
}

export interface PrSummary {
  id: number;
  number: number;
  title: string;
  url: string;
  state: 'open' | 'closed' | 'merged';
  reviewStatus: 'pending' | 'approved' | 'changes_requested' | 'commented';
  author: string;
  repoOwner: string;
  repoName: string;
  createdAt: string;
  updatedAt: string;
  readyAt: string | null;
  daysSinceReady: number | null;
  statusState: 'success' | 'failure' | 'pending' | 'error' | null;
}

export interface ReviewRequest {
  id: number;
  number: number;
  title: string;
  url: string;
  state: 'open' | 'closed' | 'merged';
  reviewStatus: 'pending' | 'approved' | 'changes_requested' | 'commented';
  author: string;
  repoOwner: string;
  repoName: string;
  createdAt: string;
  updatedAt: string;
  reviewRequestedAt: string | null;
  daysWaiting: number | null;
  requestedReviewer: string | null;
  reviewCategory: string; // 'human' or bot name (e.g., 'snyk', 'renovate', 'buildagencygitapitoken')
  statusState: 'success' | 'failure' | 'pending' | 'error' | null;
}

