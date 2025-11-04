# GitHub Review Manager

A native macOS application for managing GitHub PR reviews with menu bar integration. Built with Swift and SwiftUI.

## Features

- macOS menu bar integration
- View your open PRs across all repositories
- Track review requests assigned to you
- Display days since PRs were marked ready for review
- Display days waiting for review requests
- Dismiss PRs to hide them from the list
- Automatic GitHub authentication via `gh` CLI or environment variable
- Clean, modern native UI

## Prerequisites

- macOS 12.0 or later
- Swift toolchain (included with macOS, or install from [swift.org](https://swift.org/downloads))
- Command Line Tools (if not using full Xcode):
  ```bash
  xcode-select --install
  ```

## Quick Start

The easiest way to build and run:

```bash
make run
```

This will build the app, remove quarantine attributes, and launch it automatically.

## Build

Build the application:

```bash
make build
```

Or use the build script directly:

```bash
cd GitHubReviewManager && ./build.sh
```

The build process:
- Compiles all Swift files using `swiftc`
- Creates the `.app` bundle structure
- Copies Info.plist and resources
- Code signs with ad-hoc signature
- Outputs to `GitHubReviewManager/.build/GitHubReviewManager.app`

## Run

Run the app (builds first if needed):

```bash
make run
```

Or open the already-built app:

```bash
make open
```

## Install

Install to `/Applications`:

```bash
make install
```

The app will be available in Applications and Spotlight.

## Package for Distribution

### Code Signing

For development, ad-hoc signing is done automatically. For distribution, sign with your Developer ID:

```bash
make sign-dist SIGNING_IDENTITY="Developer ID Application: Your Name (TEAM_ID)"
```

### Create DMG

Create a distributable DMG:

```bash
make dmg
```

This creates `GitHubReviewManager.dmg` in the project root. Alternatively, you can distribute the `.app` bundle directly.

## Other Commands

- `make clean` - Remove build artifacts
- `make check` - Check if build exists
- `make help` - Show all available commands

## First Launch

On first launch, macOS may show a security warning. If you see "GitHubReviewManager.app cannot be opened because the developer cannot be verified":
1. Right-click the app
2. Select "Open"
3. Confirm in the dialog that you want to open it

This is normal for apps that aren't notarized by Apple. For distribution, consider using Developer ID signing and notarization.

## Setup

### GitHub Authentication

The app supports two methods for GitHub authentication (in order of preference):

1. **GitHub CLI (`gh`)** - If you have GitHub CLI installed and authenticated:
   ```bash
   gh auth login
   ```

2. **Environment Variable** - Set a GitHub Personal Access Token:
   ```bash
   export GITHUB_TOKEN=your_token_here
   ```

   Or add it to a `.env` file (make sure it's in `.gitignore`).

If neither method is available, the app will not be able to fetch PR data.

#### GitHub Token Scopes

If using a Personal Access Token, it needs the following scopes:
- `repo` (for private repositories)
- `public_repo` (for public repositories)

### Dismissing PRs

You can dismiss PRs from the list by clicking the dismiss button. Dismissed PRs are stored locally using UserDefaults and will remain hidden until they are closed or you clear the dismissed list. The dismissed state persists across app launches.

## Project Structure

```
GitHubReviewManager/
├── GitHubReviewManager/        # Swift source code
│   ├── Models/                 # Data models (PRSummary, ReviewRequest, etc.)
│   ├── Services/               # Business logic (GitHubService, AuthService, etc.)
│   ├── Views/                  # SwiftUI views
│   │   └── Components/         # Reusable UI components
│   ├── Utilities/              # Helper utilities
│   ├── App.swift               # App entry point
│   └── AppDelegate.swift       # App delegate
├── build.sh                    # Build script
├── Package.swift               # Swift Package Manager manifest
└── README.md                   # Detailed project documentation
```

## Development

See `GitHubReviewManager/README.md` for detailed development documentation and `GitHubReviewManager/BUILD_WITHOUT_XCODE.md` for advanced build options.

## License

MIT
