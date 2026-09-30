#!/bin/bash
set -e

VERSION="${1:?Usage: package-app.sh <version>}"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$REPO/.build/package"
APP="$BUILD_DIR/ClaudeUsage.app"

echo "Building universal binary..."
swift build -c release --package-path "$REPO" --arch arm64 --arch x86_64

BIN_DIR="$(swift build -c release --package-path "$REPO" --arch arm64 --arch x86_64 --show-bin-path 2>/dev/null | tail -1)"
BINARY="$BIN_DIR/ClaudeUsage"
if [ ! -f "$BINARY" ]; then
    echo "error: expected universal binary at $BINARY, not found" >&2
    exit 1
fi

echo "Assembling app bundle..."
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BINARY" "$APP/Contents/MacOS/ClaudeUsage"

sed "s/\$(VERSION)/$VERSION/g" "$REPO/Packaging/Info.plist" > "$APP/Contents/Info.plist"

if [ -f "$REPO/Packaging/AppIcon.icns" ]; then
    cp "$REPO/Packaging/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
fi

echo "Signing (ad-hoc)..."
codesign --force --deep -s - "$APP"

echo "Packaged: $APP"
