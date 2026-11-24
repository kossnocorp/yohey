#!/bin/bash
set -euo pipefail
: "${2:?Usage: secrets:sync release-app|release-website OWNER/REPO}"
case "$1" in
release-app) keys=(YOHEY_CERTIFICATE_BASE64 YOHEY_CERTIFICATE_PASSWORD YOHEY_APPLE_ID YOHEY_TEAM_ID YOHEY_APPLE_PASSWORD);;
release-website) keys=(CLOUDFLARE_ACCOUNT_ID CLOUDFLARE_API_TOKEN);;
*) exit 2;;
esac
values=()
for key in "${keys[@]}"; do
  value=$(fnox get "$key")
  if [[ -z $value || $value == placeholder-* ]]; then echo "Replace $key in fnox first" >&2; exit 1; fi
  values+=("$value")
done
for i in "${!keys[@]}"; do printf %s "${values[i]}" | gh secret set "${keys[i]}" --repo "$2" --env "$1"; done
