#!/bin/bash
# Installs the latest DockPeek release to /Applications.
#   curl -fsSL https://raw.githubusercontent.com/ahmetrende/dockpeek/main/scripts/install.sh | bash
set -euo pipefail

ZIP_URL="${DOCKPEEK_ZIP_URL:-https://github.com/ahmetrende/dockpeek/releases/latest/download/DockPeek.zip}"
DEST="/Applications/DockPeek.app"
# Every DockPeek release is signed with this certificate. Anything else is refused.
REQUIREMENT='identifier "io.github.ahmetrende.dockpeek" and certificate leaf = H"c02a1909029daad5191cfe8393861cb3d794aeed"'

# Everything runs inside main, so a download that stops in the middle runs nothing.
main() {
    [[ "$(uname -s)" == "Darwin" ]] || { echo "DockPeek runs on macOS only."; exit 1; }
    MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
    (( MAJOR >= 27 )) || { echo "DockPeek needs macOS 27 or later."; exit 1; }
    [[ "$(uname -m)" == "arm64" ]] || { echo "DockPeek needs a Mac with Apple silicon."; exit 1; }

    WORK="$(mktemp -d)"
    trap 'rm -rf "$WORK"' EXIT

    echo "Downloading $ZIP_URL"
    curl -fsSL "$ZIP_URL" -o "$WORK/DockPeek.zip"
    ditto -x -k "$WORK/DockPeek.zip" "$WORK"
    if ! codesign --verify --strict -R="$REQUIREMENT" "$WORK/DockPeek.app" 2>/dev/null; then
        echo "The download is not signed with the DockPeek certificate. Nothing was installed."
        exit 1
    fi

    pkill -x DockPeek || true
    rm -rf "$DEST"
    ditto "$WORK/DockPeek.app" "$DEST"
    # curl does not mark downloads as quarantined. This only makes sure.
    xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
    open "$DEST"

    # The text and its end marker stay at the start of the line. Spaces would show in the output.
    cat <<'TEXT'
DockPeek is installed and running.

One step is left. Only a person can do it:
  System Settings > Privacy & Security > Accessibility: turn on DockPeek.
  System Settings > Privacy & Security > Screen Recording: turn on DockPeek.
DockPeek's settings window shows both and has buttons that open these pages.
TEXT
}

main "$@"
