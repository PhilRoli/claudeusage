#!/bin/bash
# scripts/package-app.sh <version>
set -e
REPO="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.0.0-dev}"
OUT="$REPO/.build/package/ClaudeUsage.app"

cd "$REPO"
swift build -c release
rm -rf "$OUT"
mkdir -p "$OUT/Contents/MacOS"
cp "$(swift build -c release --show-bin-path)/ClaudeUsage" "$OUT/Contents/MacOS/ClaudeUsage"
cp Packaging/Info.plist "$OUT/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$OUT/Contents/Info.plist"
echo "Packaged $OUT"
