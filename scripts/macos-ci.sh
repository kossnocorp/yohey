#!/bin/bash
set -euo pipefail
: "${RUNNER_TEMP:?GitHub-hosted macOS runner required}"
keychain="$RUNNER_TEMP/yohey-signing.keychain-db"
if [[ ${1:-} == cleanup ]]; then
  security default-keychain -d user -s login.keychain-db
  security delete-keychain "$keychain" || true
  rm -f "$RUNNER_TEMP/yohey.p12"
  exit
fi
umask 077
printf %s "${YOHEY_CERTIFICATE_BASE64:?}" | base64 -D > "$RUNNER_TEMP/yohey.p12"
password=$(openssl rand -hex 32)
security create-keychain -p "$password" "$keychain"
security set-keychain-settings -lut 21600 "$keychain"
security unlock-keychain -p "$password" "$keychain"
security import "$RUNNER_TEMP/yohey.p12" -k "$keychain" -P "${YOHEY_CERTIFICATE_PASSWORD:?}" -T /usr/bin/codesign -T /usr/bin/security
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain" >/dev/null
security list-keychains -d user -s "$keychain" login.keychain-db
security default-keychain -d user -s "$keychain"
bash pkgs/macos/scripts/notarize-setup.sh
