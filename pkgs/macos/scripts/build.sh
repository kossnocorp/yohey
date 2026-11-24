#!/bin/bash
set -euo pipefail
args=()
if [[ -n ${YOHEY_VERSION:-} ]]; then args+=("MARKETING_VERSION=$YOHEY_VERSION"); fi
xcodebuild -quiet -project pkgs/macos/Yohey.xcodeproj -scheme Yohey -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO ${args[@]+"${args[@]}"} build
