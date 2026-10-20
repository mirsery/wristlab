#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check_specs.py
./scripts/swift-test.sh --package-path Packages/WristlabCore
./scripts/swift-test.sh
