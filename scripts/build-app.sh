#!/bin/bash
# Builds DockPeek.app and signs it.
#   scripts/build-app.sh                   build and install to /Applications
#   scripts/build-app.sh --release-to DIR  build a release copy into DIR/DockPeek.app
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SCRATCH="$HOME/Library/Caches/DockPeek-build"
STAGE="$SCRATCH/DockPeek.app"
DEST="/Applications/DockPeek.app"
OLD_DEST="$HOME/Applications/DockPeek.app"
IDENTITY="${DOCKPEEK_SIGN_IDENTITY:-DockPeek Signing}"
RELEASE_DIR=""

if [[ "${1:-}" == "--release-to" ]]; then
    RELEASE_DIR="${2:?usage: build-app.sh --release-to DIR}"
fi

swift build -c release --package-path "$ROOT" --scratch-path "$SCRATCH"
BIN_DIR="$(swift build -c release --package-path "$ROOT" --scratch-path "$SCRATCH" --show-bin-path)"

rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$BIN_DIR/DockPeek" "$STAGE/Contents/MacOS/DockPeek"
# Debug symbols hold absolute source paths, which show the builder's user name.
strip -S "$STAGE/Contents/MacOS/DockPeek"
cp "$ROOT/Resources/Info.plist" "$STAGE/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$STAGE/Contents/Resources/AppIcon.icns"
# The settings window shows the time of the last commit, in UTC.
COMMIT_DATE="$(TZ=UTC git -C "$ROOT" log -1 --date=format-local:'%Y-%m-%d %H:%M' --format=%cd)"
plutil -insert DockPeekCommitDate -string "$COMMIT_DATE" "$STAGE/Contents/Info.plist"
if [[ -n "$RELEASE_DIR" ]]; then
    # Only release builds check GitHub for updates.
    plutil -insert DockPeekReleaseBuild -bool true "$STAGE/Contents/Info.plist"
fi

# Signing comes last: any later change to the bundle breaks the signature.
BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw "$ROOT/Resources/Info.plist")"
codesign --force --sign "$IDENTITY" --identifier "$BUNDLE_ID" "$STAGE"
codesign --verify --strict "$STAGE"

if [[ -n "$RELEASE_DIR" ]]; then
    mkdir -p "$RELEASE_DIR"
    rm -rf "$RELEASE_DIR/DockPeek.app"
    ditto "$STAGE" "$RELEASE_DIR/DockPeek.app"
    echo "Release build: $RELEASE_DIR/DockPeek.app"
    exit 0
fi

# The running copy must stop before its bundle is replaced.
pkill -x DockPeek || true
rm -rf "$DEST"
ditto "$STAGE" "$DEST"
# Older versions installed here. One copy per Mac keeps Spotlight and login items on the right one.
rm -rf "$OLD_DEST"
echo "Installed: $DEST"
