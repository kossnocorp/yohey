#!/bin/bash
set -euo pipefail
: "${YOHEY_TEAM_ID:?Set your Apple Team ID}"
: "${YOHEY_SIGNING_IDENTITY:?Set the shared Developer ID Application signing identity}"
bundle=build/Build/Products/Release/Yohey.app
codesign --force --timestamp --options runtime --sign "$YOHEY_SIGNING_IDENTITY" "$bundle"
codesign --verify --strict -R="anchor apple generic and identifier \"fyi.yohey.app\" and certificate leaf[subject.OU] = \"$YOHEY_TEAM_ID\" and certificate leaf[field.1.2.840.113635.100.6.1.13] exists" "$bundle"
