#!/bin/bash
# Create a stable, self-signed CODE-SIGNING certificate in your login keychain so
# the Accessibility / Input-Monitoring grant for WakeGuard PERSISTS across rebuilds.
#
# Why: macOS ties the grant to the app's code signature. An ad-hoc signature
# changes on every build, which silently invalidates the permission (the toggle
# may still look "on" in Settings, but the new binary no longer matches). Signing
# every build with the SAME self-signed identity keeps the signature stable, so
# the grant sticks.
#
# Run this ONCE. Afterwards, ./scripts/build-app.sh signs with it automatically.
# Removing it later: open Keychain Access → login → delete "WakeGuard Self-Signed".
set -euo pipefail

NAME="WakeGuard Self-Signed"

if security find-certificate -c "$NAME" >/dev/null 2>&1; then
    echo "Certificate \"$NAME\" already exists in your keychain — nothing to do."
    exit 0
fi

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/openssl.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions = v3
prompt = no
[dn]
CN = $NAME
[v3]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
EOF

echo "Generating a self-signed code-signing certificate…"
openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
    -days 3650 -config "$TMP/openssl.cnf" >/dev/null 2>&1
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/identity.p12" -passout pass: -name "$NAME" >/dev/null 2>&1

echo "Importing it into your login keychain…"
security import "$TMP/identity.p12" \
    -k "$HOME/Library/Keychains/login.keychain-db" \
    -P "" -A -T /usr/bin/codesign >/dev/null

echo
echo "Done — created \"$NAME\"."
echo "Next:"
echo "  1. ./scripts/build-app.sh --install      # now signs with the stable identity"
echo "  2. tccutil reset Accessibility com.skopetskyi.wakeguard   # clear any stale grant"
echo "  3. Launch WakeGuard, grant Accessibility once — it now persists across rebuilds."
echo "(codesign may ask once to 'Always Allow' use of the key — click Always Allow.)"
