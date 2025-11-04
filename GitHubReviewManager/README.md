# GitHub Review Manager (Swift/SwiftUI)

Native macOS application for managing GitHub PR reviews, migrated from Electron/TypeScript.

## Project Setup

This is a SwiftUI macOS application. You have two options:

### Option 1: Build Without Xcode (Recommended for CLI-first workflow)

```bash
cd GitHubReviewManager
./build.sh
open .build/GitHubReviewManager.app
```

See [BUILD_WITHOUT_XCODE.md](BUILD_WITHOUT_XCODE.md) for details.

### Option 2: Use Xcode (Traditional IDE approach)

1. **Create Xcode Project:**
   - Open Xcode
   - File → New → Project
   - Choose "macOS" → "App"
   - Product Name: `GitHubReviewManager`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Organization Identifier: `com.github-review-manager`
   - Bundle Identifier: `com.github-review-manager.app`

2. **Copy Source Files:**
   - Copy all files from `GitHubReviewManager/GitHubReviewManager/` into your Xcode project
   - Maintain the folder structure (Views, Models, Services, Utilities)

3. **Add Assets:**
   - Copy `assets/icon.png` to the Xcode project's Assets.xcassets or include it in the bundle
   - Ensure the icon is accessible at runtime (may need to add to "Copy Bundle Resources" in Build Phases)

4. **Configure Info.plist:**
   - Set `CFBundleName` to "GitHub Review Manager"
   - Set `LSApplicationCategoryType` to "public.app-category.productivity"
   - Ensure `LSUIElement` is set to `YES` (or `true`) to hide the dock icon

5. **Build and Run:**
   - Select the scheme and target
   - Build (⌘B) and Run (⌘R)

## Features

- Native macOS tray menu integration
- GitHub GraphQL API integration
- Authentication via `gh` CLI or `GITHUB_TOKEN` environment variable
- PR review request tracking
- Bot categorization (Snyk-io, Renovate, Promotions, etc.)
- Slack message formatting and clipboard copy
- Dismissed PR persistence
- Non-focusing popover (compatible with tiling window managers)

## Architecture

- **Models**: `PRSummary`, `ReviewRequest`, `PRReview` with Codable conformance
- **Services**:
  - `GitHubService`: GraphQL API client with caching
  - `AuthService`: Token resolution (gh CLI + env var)
  - `StorageService`: Dismissed PRs persistence via UserDefaults
  - `TrayMenuManager`: NSStatusItem and NSPopover management
- **Views**: SwiftUI views for PR list, status pills, copy buttons
- **Utilities**:
  - `BotCategorizer`: Bot identification logic
  - `SlackFormatter`: Message formatting for Slack

## Key Differences from Electron Version

- **No IPC layer**: Everything runs in a single process
- **Native popover**: Uses NSPopover instead of BrowserWindow
- **Better focus handling**: Native popover behavior avoids window manager conflicts
- **Simpler storage**: UserDefaults instead of JSON file
- **Swift async/await**: Modern concurrency model

## Testing

After building, test the following:
1. Authentication (gh CLI or env var)
2. PR fetching (user open PRs and review requests)
3. Bot categorization
4. Dismissed PR persistence
5. Copy to clipboard (Slack formatting)
6. External link opening (should focus browser)
7. Tray icon visibility
8. Popover show/hide
9. Esc key to close popover

## Notes

- The app runs as a menu bar-only application (no dock icon)
- Popover uses `.transient` behavior to avoid focus stealing
- Links open via `NSWorkspace.shared.open()` which should properly focus the browser
- Tray icon loads from bundle resources; falls back to programmatic icon if not found

