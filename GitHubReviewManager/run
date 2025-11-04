#!/bin/bash
# Run GitHub Review Manager and capture output

cd "$(dirname "$0")"
APP_PATH=".build/GitHubReviewManager.app/Contents/MacOS/GitHubReviewManager"

echo "Starting GitHub Review Manager..."
echo "Debug output will appear below:"
echo "---"
echo ""

# Run the app and capture output
"$APP_PATH" 2>&1 | while IFS= read -r line; do
    echo "[APP] $line"
done

