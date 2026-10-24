#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/stdd --project-check
python3 scripts/check_specs.py
# WRX-001: WatchConnectivity calls sendMessage handlers off the main actor; pass WatchRefreshHandlers, not closure literals.
if grep -rnE '(replyHandler|errorHandler):[[:space:]]*\{' Apps --include='*.swift'; then
  echo "WatchConnectivity handlers must be @Sendable values (see WatchRefreshHandlers)" >&2
  exit 1
fi
./scripts/swift-test.sh --package-path Packages/WristlabCore
./scripts/swift-test.sh
python3 scripts/test-phone-health.py
