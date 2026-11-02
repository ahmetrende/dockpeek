#!/bin/bash
# Makes DockPeek.dmg. Its window shows DockPeek, an arrow and Applications on Resources/DMGBackground.tiff.
#   scripts/make-dmg.sh <DockPeek.app> <output.dmg>
# Finder writes the window layout, so macOS may ask once to let this app control Finder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VOLUME=/Volumes/DockPeek

stop() { echo "Stopped: $1"; exit 1; }

[[ $# -eq 2 ]] || stop "usage: scripts/make-dmg.sh <DockPeek.app> <output.dmg>"
APP="$1"
DMG="$2"
[[ -d "$APP" ]] || stop "no app at $APP"
[[ -e "$VOLUME" ]] && stop "$VOLUME is in use. Eject it first."

# The background's alias in .DS_Store keeps the path of the work image, so it must not be under
# $HOME or the per-user temp folder.
WORK="$(mktemp -d /tmp/DockPeek-dmg.XXXXXX)"
trap 'diskutil eject "$VOLUME" >/dev/null 2>&1 || true; rm -rf "$WORK"' EXIT

mkdir -p "$WORK/src/.background"
ditto "$APP" "$WORK/src/DockPeek.app"
ln -s /Applications "$WORK/src/Applications"
cp "$ROOT/Resources/DMGBackground.tiff" "$WORK/src/.background/background.tiff"
hdiutil create -quiet -volname DockPeek -srcfolder "$WORK/src" -format UDRW "$WORK/rw.dmg"
hdiutil attach -quiet -readwrite -noverify -noautoopen -mountpoint "$VOLUME" "$WORK/rw.dmg"

# The icon positions and the window size match scripts/make-dmg-background.swift.
osascript <<'EOF' || stop "Finder did not lay out the window. Allow control of Finder in System Settings > Privacy & Security > Automation."
tell application "Finder"
    tell disk "DockPeek"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        -- 400 pt of content plus the 32 pt title bar (macOS 27). The path bar is a global Finder
        -- setting, so it is not set here. When it is on, it covers the empty bottom 30 pt.
        set bounds of container window to {200, 120, 840, 552}
        set viewOptions to icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 128
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "DockPeek.app" of container window to {170, 180}
        set position of item "Applications" of container window to {470, 180}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF

# Finder writes paths into .DS_Store. The DMG is public, so it must not name the user
# or the per-user temp folder (/var/folders/xx/<this ID>/T).
sync
[[ -f "$VOLUME/.DS_Store" ]] || stop "Finder did not write the window layout"
user_folder="$(basename "$(dirname "$(getconf DARWIN_USER_TEMP_DIR)")")"
for file in "$VOLUME/.DS_Store" "$VOLUME/.background/background.tiff"; do
    content="$(xxd -p "$file" | tr -d '\n')"
    for name in "$USER" "$(id -F)" "$user_folder"; do
        for encoding in UTF-8 UTF-16BE UTF-16LE; do
            needle="$(printf '%s' "$name" | iconv -f UTF-8 -t "$encoding" | xxd -p | tr -d '\n')"
            [[ "$content" == *"$needle"* ]] && stop "$(basename "$file") contains \"$name\" ($encoding)"
        done
    done
done
rm -rf "$VOLUME/.fseventsd"

diskutil eject "$VOLUME" >/dev/null
hdiutil convert -quiet "$WORK/rw.dmg" -format UDZO -ov -o "$DMG"
echo "Written: $DMG"
