#!/bin/bash
# Publishes the version in Resources/Info.plist as a GitHub release with DockPeek.dmg and DockPeek.zip.
#   scripts/release.sh            build, check and publish
#   scripts/release.sh --dry-run  build and check only; skips the git checks and the upload
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="$(plutil -extract CFBundleShortVersionString raw "$ROOT/Resources/Info.plist")"
TAG="v$VERSION"
OUT="$HOME/Library/Caches/DockPeek-release/$VERSION"
DRY_RUN=""

stop() { echo "Stopped: $1"; exit 1; }

case "${1:-}" in
    "") ;;
    --dry-run) DRY_RUN=1 ;;
    *) stop "unknown option: $1" ;;
esac

cd "$ROOT"
if [[ -z "$DRY_RUN" ]]; then
    [[ "$(git branch --show-current)" == "main" ]] || stop "not on main"
    [[ -z "$(git status --porcelain)" ]] || stop "the working tree has changes"
    git fetch -q origin main
    [[ "$(git rev-parse HEAD)" == "$(git rev-parse origin/main)" ]] || stop "HEAD is not the same as origin/main"
    gh auth status >/dev/null 2>&1 || stop "gh is not logged in"
    git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && stop "tag $TAG already exists"
    git ls-remote --exit-code --tags origin "refs/tags/$TAG" >/dev/null 2>&1 && stop "tag $TAG already exists on origin"
    gh release view "$TAG" >/dev/null 2>&1 && stop "$TAG already exists"
fi

swift test --scratch-path "$HOME/Library/Caches/DockPeek-build"

rm -rf "$OUT"
"$ROOT/scripts/build-app.sh" --release-to "$OUT"
"$ROOT/scripts/check-package.sh" "$OUT/DockPeek.app" --release

ditto -c -k --keepParent "$OUT/DockPeek.app" "$OUT/DockPeek.zip"
mkdir "$OUT/dmg"
ditto "$OUT/DockPeek.app" "$OUT/dmg/DockPeek.app"
ln -s /Applications "$OUT/dmg/Applications"
hdiutil create -quiet -volname DockPeek -srcfolder "$OUT/dmg" -format UDZO -ov "$OUT/DockPeek.dmg"

if [[ -n "$DRY_RUN" ]]; then
    echo "Dry run: not published. Files are in $OUT"
    exit 0
fi
gh release create "$TAG" "$OUT/DockPeek.dmg" "$OUT/DockPeek.zip" \
    --title "DockPeek $VERSION" --generate-notes --target main
git fetch --tags -q origin
echo "Published: $(gh release view "$TAG" --json url -q .url)"
