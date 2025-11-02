import { ipcMain, app } from 'electron';
import { GitHubClient } from './github/client';
import { getGitHubToken } from './github/auth';
import {
  loadDismissedPrs,
  dismissPr as storeDismissPr,
  filterDismissed,
} from './storage/dismissedPrStore';
import type { IpcChannels } from '../common/ipcChannels';

let githubClient: GitHubClient | null = null;
let authInitializationPromise: Promise<void> | null = null;

// Cache for GitHub data with timestamps
interface CachedData<T> {
  data: T;
  timestamp: number;
}

let cachedUserPrs: CachedData<IpcChannels['github:getUserOpenPrs']['response']> | null = null;
let cachedReviewRequests: CachedData<IpcChannels['github:getReviewRequests']['response']> | null = null;

// Cache TTL: 5 minutes
const CACHE_TTL_MS = 5 * 60 * 1000;

export function initializeGitHubClient(token?: string): void {
  githubClient = new GitHubClient(token);
}

export async function initializeGitHubClientAsync(): Promise<void> {
  const token = await getGitHubToken();
  if (token) {
    githubClient = new GitHubClient(token);
  } else {
    githubClient = null;
  }
}

export async function initializeStorage(): Promise<void> {
  await loadDismissedPrs();
}

async function ensureClientInitialized(): Promise<void> {
  if (authInitializationPromise) {
    await authInitializationPromise;
  }
}

export function registerIpcHandlers(): void {
  // Initialize GitHub client asynchronously with token resolution
  authInitializationPromise = initializeGitHubClientAsync().catch(() => {
    // Silent failure - will use mock data if needed
    githubClient = null;
  });

  // Initialize storage
  initializeStorage().catch(() => {
    // Silent failure
  });

  ipcMain.handle(
    'github:getPrReviews',
    async (
      _event,
      owner: string,
      repo: string
    ): Promise<IpcChannels['github:getPrReviews']['response']> => {
      if (!githubClient) {
        // Fallback to mock data if client not initialized
        const mockClient = new GitHubClient();
        return mockClient.getPrReviews(owner, repo);
      }

      try {
        return await githubClient.getPrReviews(owner, repo);
      } catch (error) {
        throw new Error(
          `Failed to get PR reviews: ${error instanceof Error ? error.message : 'Unknown error'}`
        );
      }
    }
  );

  ipcMain.handle(
    'github:getUserOpenPrs',
    async (
      _event,
      forceRefresh = false
    ): Promise<IpcChannels['github:getUserOpenPrs']['response']> => {
      // Return cached data if fresh and not forcing refresh
      if (!forceRefresh && cachedUserPrs) {
        const age = Date.now() - cachedUserPrs.timestamp;
        if (age < CACHE_TTL_MS) {
          return cachedUserPrs.data;
        }
      }

      // Wait for authentication to complete if still initializing
      await ensureClientInitialized();

      if (!githubClient) {
        // Fallback to mock data if client not initialized
        const mockClient = new GitHubClient();
        const prs = await mockClient.listUserOpenPrs();
        const filtered = filterDismissed(prs);
        cachedUserPrs = { data: filtered, timestamp: Date.now() };
        return filtered;
      }

      try {
        const prs = await githubClient.listUserOpenPrs();
        const filtered = filterDismissed(prs);
        cachedUserPrs = { data: filtered, timestamp: Date.now() };
        return filtered;
      } catch (error) {
        // Return cached data on error if available
        if (cachedUserPrs) {
          return cachedUserPrs.data;
        }
        throw new Error(
          `Failed to get user open PRs: ${error instanceof Error ? error.message : 'Unknown error'}`
        );
      }
    }
  );

  ipcMain.handle(
    'github:getReviewRequests',
    async (
      _event,
      forceRefresh = false
    ): Promise<IpcChannels['github:getReviewRequests']['response']> => {
      // Return cached data if fresh and not forcing refresh
      if (!forceRefresh && cachedReviewRequests) {
        const age = Date.now() - cachedReviewRequests.timestamp;
        if (age < CACHE_TTL_MS) {
          return cachedReviewRequests.data;
        }
      }

      // Wait for authentication to complete if still initializing
      await ensureClientInitialized();

      if (!githubClient) {
        // Fallback to mock data if client not initialized
        const mockClient = new GitHubClient();
        const requests = await mockClient.listRequestedReviews();
        const filtered = filterDismissed(requests);
        cachedReviewRequests = { data: filtered, timestamp: Date.now() };
        return filtered;
      }

      try {
        const requests = await githubClient.listRequestedReviews();
        const filtered = filterDismissed(requests);
        cachedReviewRequests = { data: filtered, timestamp: Date.now() };
        return filtered;
      } catch (error) {
        // Return cached data on error if available
        if (cachedReviewRequests) {
          return cachedReviewRequests.data;
        }
        throw new Error(
          `Failed to get review requests: ${error instanceof Error ? error.message : 'Unknown error'}`
        );
      }
    }
  );

  ipcMain.handle(
    'github:dismissPr',
    async (_event, prId: number): Promise<IpcChannels['github:dismissPr']['response']> => {
      try {
        await storeDismissPr(prId);
        // Invalidate cache since dismissed PRs should be filtered out
        cachedUserPrs = null;
        cachedReviewRequests = null;
      } catch (error) {
        throw new Error(
          `Failed to dismiss PR: ${error instanceof Error ? error.message : 'Unknown error'}`
        );
      }
    }
  );

  ipcMain.handle('app:quit', () => {
    app.quit();
  });
}

