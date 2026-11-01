#!/bin/bash
# Creates a self-signed code signing certificate in the login keychain.
# DockPeek builds are signed with it, so macOS keeps permissions across updates.
#   scripts/make-certificate.sh ["Certificate Name"]
set -euo pipefail

NAME="${1:-DockPeek Signing}"
DAYS=7300
OPENSSL=/usr/bin/openssl

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "A certificate named \"$NAME\" already exists. Nothing to do."
    exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Only a name: an email address would ship inside every signed app.
cat > "$WORK/cert.conf" <<CONF
[req]
distinguished_name = dn
prompt = no
x509_extensions = ext
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CONF

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days "$DAYS" -config "$WORK/cert.conf" \
    -keyout "$WORK/key.pem" -out "$WORK/cert.pem" 2>/dev/null
# A random one-time password protects the key only while it moves into the keychain.
PASS="$("$OPENSSL" rand -hex 16)"
"$OPENSSL" pkcs12 -export -inkey "$WORK/key.pem" -in "$WORK/cert.pem" -name "$NAME" \
    -out "$WORK/identity.p12" -passout "pass:$PASS"
security import "$WORK/identity.p12" -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "$PASS" -T /usr/bin/codesign >/dev/null

echo "Created \"$NAME\", valid for $DAYS days."
echo "Back it up: Keychain Access > \"$NAME\" > File > Export Items (.p12)."
