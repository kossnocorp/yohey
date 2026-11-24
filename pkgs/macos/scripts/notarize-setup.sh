#!/bin/bash
# Store notarization credentials in Keychain; prompt if no password was supplied.
set -euo pipefail

: "${YOHEY_APPLE_ID:?Set YOHEY_APPLE_ID to your Apple Developer account email}"
: "${YOHEY_TEAM_ID:?Set YOHEY_TEAM_ID to your Apple Developer team ID}"
: "${YOHEY_NOTARY_PROFILE:?Set the shared Keychain notarization profile}"

args=(
    notarytool store-credentials "$YOHEY_NOTARY_PROFILE"
    --apple-id "$YOHEY_APPLE_ID"
    --team-id "$YOHEY_TEAM_ID"
)
if [[ -n ${YOHEY_APPLE_PASSWORD:-} ]]; then
    args+=(--password "$YOHEY_APPLE_PASSWORD")
fi
xcrun "${args[@]}"
