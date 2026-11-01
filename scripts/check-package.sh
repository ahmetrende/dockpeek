#!/bin/bash
# Checks a built DockPeek.app for private data before it is published.
#   scripts/check-package.sh path/to/DockPeek.app [--release]
# Prints each problem. Exits 1 if there is one.
set -uo pipefail

APP="${1:?usage: check-package.sh DockPeek.app [--release]}"
MODE="${2:-}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$APP/Contents/MacOS/DockPeek"
PLIST="$APP/Contents/Info.plist"
ALLOWED="CFBundleExecutable CFBundleIconFile CFBundleIdentifier CFBundleName CFBundlePackageType CFBundleShortVersionString CFBundleVersion LSMinimumSystemVersion LSUIElement NSHighResolutionCapable DockPeekCommitDate DockPeekReleaseBuild"
problems=0
fail() { echo "FAIL: $1"; problems=$((problems + 1)); }

# 1. No user paths in the binary.
grep -q -a '/Users/' "$BIN" && fail "the binary contains /Users/ paths"
# 2. No debug symbols with source paths. The output goes to a variable first:
#    with pipefail, grep -q would stop nm early and hide a match.
SYMBOLS="$(nm -ap "$BIN" 2>/dev/null)"
grep -q -E ' (SO|OSO) ' <<<"$SYMBOLS" && fail "the binary has debug source-path symbols"
# 3. No email address in the signing certificate.
CERTS="$(mktemp -d)"
trap 'rm -rf "$CERTS"' EXIT
(cd "$CERTS" && codesign -d --extract-certificates "$APP" >/dev/null 2>&1)
SUBJECT="$(/usr/bin/openssl x509 -inform der -in "$CERTS/codesign0" -noout -subject 2>/dev/null)"
case "$SUBJECT" in
    "") fail "no signing certificate" ;;
    *emailAddress* | *@*) fail "the certificate subject has an email address" ;;
esac
# 4. Only known Info.plist keys.
for key in $(plutil -p "$PLIST" | sed -n 's/^  "\([^"]*\)" =>.*/\1/p'); do
    case " $ALLOWED " in
        *" $key "*) ;;
        *) fail "unexpected Info.plist key: $key" ;;
    esac
done
# 5. A release checks for updates and is signed with the published certificate.
if [[ "$MODE" == "--release" ]]; then
    [[ "$(plutil -extract DockPeekReleaseBuild raw "$PLIST" 2>/dev/null)" == "true" ]] \
        || fail "DockPeekReleaseBuild is not set"
    REQUIREMENT="$(sed -n "s/^REQUIREMENT='\(.*\)'$/\1/p" "$ROOT/scripts/install.sh")"
    codesign --verify --strict -R="$REQUIREMENT" "$APP" 2>/dev/null \
        || fail "not signed with the certificate in scripts/install.sh"
fi

if (( problems > 0 )); then
    echo "$problems problem(s) in $APP"
    exit 1
fi
echo "Package OK: $APP"
