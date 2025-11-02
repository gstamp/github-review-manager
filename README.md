# GitHub Review Manager

An Electron application for managing GitHub PR reviews with macOS tray integration.

## Features

- macOS menu bar (tray) integration
- View your open PRs across all repositories
- Track review requests assigned to you
- Display days since PRs were marked ready for review
- Display days waiting for review requests
- Dismiss PRs to hide them from the list
- Automatic GitHub authentication via `gh` CLI or environment variable
- Clean, modern UI for viewing review statuses

## Prerequisites

- Node.js 18+ and pnpm
- macOS (for tray functionality)
- GitHub Personal Access Token (optional, for real API access)

## Setup

1. Install dependencies:
```bash
pnpm install
```

2. Set up environment variables (optional):
```bash
# Create a .env file
echo "GITHUB_TOKEN=your_github_token_here" > .env
```

If no token is provided, the app will use mock data for development.

## Development

Run the development server:
```bash
pnpm run dev
```

This will:
- Start the Vite dev server for the renderer process
- Launch Electron with hot reload

## Building

Build the application:
```bash
pnpm run build
```

This compiles TypeScript and builds the renderer bundle.

## Packaging

Package the application for macOS:
```bash
pnpm run package:mac
```

This creates a DMG installer in the `dist` directory.

## Project Structure

```
src/
├── main/           # Electron main process
│   ├── github/     # GitHub API client
│   ├── ipc.ts      # IPC handlers
│   ├── main.ts     # Main entry point
│   └── tray.ts     # Tray menu implementation
├── preload/        # Preload scripts (IPC bridge)
├── renderer/       # React renderer process
│   ├── App.tsx     # Main React component
│   └── main.tsx    # Renderer entry point
└── common/         # Shared types and utilities
    └── ipcChannels.ts
```

## Configuration

### GitHub Authentication

The app supports two methods for GitHub authentication (in order of preference):

1. **GitHub CLI (`gh`)** - If you have GitHub CLI installed and authenticated, the app will automatically use your `gh` token:
   ```bash
   gh auth login
   ```

2. **Environment Variable** - Set a GitHub Personal Access Token as an environment variable:
   ```bash
   export GITHUB_TOKEN=your_token_here
   ```

   Or add it to a `.env` file (make sure it's in `.gitignore`).

If neither method is available, the app will use mock data for development.

#### GitHub Token Scopes

If using a Personal Access Token, it needs the following scopes:
- `repo` (for private repositories)
- `public_repo` (for public repositories)

### Dismissing PRs

You can dismiss PRs from the list by clicking the × button. Dismissed PRs are stored locally and will remain hidden until they are closed or you restart the app (dismissed state is persisted across sessions).

## Scripts

- `pnpm run dev` - Start development server
- `pnpm run build` - Build the application
- `pnpm run lint` - Run ESLint
- `pnpm run typecheck` - Run TypeScript type checking
- `pnpm run package` - Package the application
- `pnpm run package:mac` - Package for macOS

## License

MIT

