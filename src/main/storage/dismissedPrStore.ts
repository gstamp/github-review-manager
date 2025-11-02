import { app } from 'electron';
import { readFile, writeFile, mkdir } from 'fs/promises';
import { join } from 'path';
import { existsSync } from 'fs';

const STORAGE_DIR = app.getPath('userData');
const STORAGE_FILE = join(STORAGE_DIR, 'dismissed-prs.json');

interface DismissedPrsData {
  dismissedIds: number[];
}

let dismissedIds: Set<number> = new Set();

/**
 * Load dismissed PR IDs from storage
 */
export async function loadDismissedPrs(): Promise<void> {
  try {
    if (!existsSync(STORAGE_FILE)) {
      dismissedIds = new Set();
      return;
    }

    const data = await readFile(STORAGE_FILE, 'utf-8');
    const parsed: DismissedPrsData = JSON.parse(data);
    dismissedIds = new Set(parsed.dismissedIds || []);
  } catch (error) {
    // If file doesn't exist or is invalid, start with empty set
    dismissedIds = new Set();
  }
}

/**
 * Save dismissed PR IDs to storage
 */
async function saveDismissedPrs(): Promise<void> {
  try {
    // Ensure directory exists
    if (!existsSync(STORAGE_DIR)) {
      await mkdir(STORAGE_DIR, { recursive: true });
    }

    const data: DismissedPrsData = {
      dismissedIds: Array.from(dismissedIds),
    };

    await writeFile(STORAGE_FILE, JSON.stringify(data, null, 2), 'utf-8');
  } catch (error) {
    // Silent failure - dismissed state won't persist
  }
}

/**
 * Dismiss a PR by ID
 */
export async function dismissPr(prId: number): Promise<void> {
  dismissedIds.add(prId);
  await saveDismissedPrs();
}

/**
 * Check if a PR is dismissed
 */
export function isPrDismissed(prId: number): boolean {
  return dismissedIds.has(prId);
}

/**
 * Filter out dismissed PRs from an array
 */
export function filterDismissed<T extends { id: number }>(prs: T[]): T[] {
  return prs.filter((pr) => !isPrDismissed(pr.id));
}

/**
 * Prune dismissed PRs that are no longer open (optional cleanup)
 */
export async function pruneDismissedPrs(openPrIds: number[]): Promise<void> {
  const openSet = new Set(openPrIds);
  const beforeSize = dismissedIds.size;
  dismissedIds = new Set([...dismissedIds].filter((id) => openSet.has(id)));

  // Only save if we actually removed something
  if (dismissedIds.size !== beforeSize) {
    await saveDismissedPrs();
  }
}

