#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "Full Xcode is required. See docs/development.md." >&2
  exit 1
fi
xcodegen generate
xcodebuild -project Wristlab.xcodeproj -scheme Wristlab -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath work/DerivedData-iOS CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Wristlab.xcodeproj -scheme WristlabWatch -configuration Debug -destination 'generic/platform=watchOS Simulator' -derivedDataPath work/DerivedData-watchOS CODE_SIGNING_ALLOWED=NO build
python3 scripts/test-widget-registration.py
python3 scripts/test-widget-registration.py --platform ios
python3 scripts/test-settings-connection.py
python3 scripts/test-phone-care.py
