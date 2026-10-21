#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/stdd --project-check
python3 scripts/check_specs.py
./scripts/swift-test.sh --package-path Packages/WristlabCore
./scripts/swift-test.sh
