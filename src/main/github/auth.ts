import { execFile } from 'child_process';
import { promisify } from 'util';

const execFileAsync = promisify(execFile);

/**
 * Attempts to get a GitHub token from `gh auth token` command, falling back to GITHUB_TOKEN env var.
 * @returns The GitHub token, or null if neither source is available
 * @throws Error if both sources fail and we want to surface the error
 */
export async function getGitHubToken(): Promise<string | null> {
  // Try gh auth token first
  try {
    const { stdout } = await execFileAsync('gh', ['auth', 'token'], {
      timeout: 5000,
    });
    const token = stdout.trim();
    if (token) {
      return token;
    }
  } catch (error) {
    // gh CLI not available or command failed - fall through to env var
  }

  // Fall back to environment variable
  const envToken = process.env.GITHUB_TOKEN;
  if (envToken) {
    return envToken;
  }

  // Neither source available
  return null;
}

