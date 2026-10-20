#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 scripts/check_specs.py
swift test --package-path Packages/WristlabCore
swift test
