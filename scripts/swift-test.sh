#!/bin/bash
set -euo pipefail
extra=()
# Some Command Line Tools releases omit automatic discovery of TestingMacros.
if [[ "$(xcode-select -p)" == *CommandLineTools* ]]; then
  plugin="$(xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
  if [[ -f "$plugin" ]]; then extra=(-Xswiftc -load-plugin-library -Xswiftc "$plugin"); fi
fi
swift test "$@" "${extra[@]}"
