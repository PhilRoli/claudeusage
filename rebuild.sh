#!/bin/bash
set -e

REPO="$(cd "$(dirname "$0")" && pwd)"
APP="/Applications/ClaudeUsage.app"

"$REPO/scripts/package-app.sh" 0.0.0-dev

echo "Stopping running instance..."
pkill -x ClaudeUsage 2>/dev/null || true
sleep 0.5

echo "Installing..."
rm -rf "$APP"
cp -R "$REPO/.build/package/ClaudeUsage.app" "$APP"

echo "Re-signing..."
codesign --remove-signature "$APP"
codesign -s - "$APP"

echo "Launching..."
open "$APP"

echo "Done."
