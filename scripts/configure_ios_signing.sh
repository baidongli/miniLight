#!/usr/bin/env bash
# Prepares App Store Connect API authentication + export options for a
# signed TestFlight build. Uses the API key only (no manual certificates):
# xcodebuild -allowProvisioningUpdates creates the signing assets.
#
# Required env (GitHub Secrets):
#   APPSTORE_API_KEY_ID        App Store Connect API key id
#   APPSTORE_API_ISSUER_ID     issuer id
#   APPSTORE_API_KEY_BASE64    base64 of the AuthKey_XXXX.p8
#   APPLE_TEAM_ID              10-char team id
set -euo pipefail

: "${APPSTORE_API_KEY_ID:?}"
: "${APPSTORE_API_ISSUER_ID:?}"
: "${APPSTORE_API_KEY_BASE64:?}"
: "${APPLE_TEAM_ID:?}"

KEYDIR="$HOME/.appstoreconnect/private_keys"
mkdir -p "$KEYDIR"
echo "$APPSTORE_API_KEY_BASE64" | base64 -d \
  > "$KEYDIR/AuthKey_${APPSTORE_API_KEY_ID}.p8"

cat > ios/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key><string>app-store</string>
  <key>teamID</key><string>${APPLE_TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>export</string>
  <key>uploadSymbols</key><true/>
</dict>
</plist>
PLIST

echo "iOS: API key + ExportOptions.plist ready."
