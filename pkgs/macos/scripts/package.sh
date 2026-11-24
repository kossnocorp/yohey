#!/bin/bash
set -euo pipefail
: "${YOHEY_TEAM_ID:?Set your Apple Team ID}"
identity=$(security find-identity -v -p codesigning | awk -v team="($YOHEY_TEAM_ID)\"" 'index($0,"\"Developer ID Application:") && index($0,team) {print $2;exit}')
: "${identity:?No Developer ID Application identity found for team}"
bundle=build/Build/Products/Release/Yohey.app
codesign --force --timestamp --options runtime --sign "$identity" "$bundle"
codesign --verify --strict "$bundle"
