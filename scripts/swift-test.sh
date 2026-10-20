#!/bin/bash
set -euo pipefail
# Command Line Tools can omit automatic discovery of the installed macro plugin.
# Avoid empty arrays: macOS ships Bash 3.2, where nounset treats them as unbound.
if [[ "$(xcode-select -p)" == *CommandLineTools* ]]; then
  plugin="$(xcode-select -p)/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"
  if [[ -f "$plugin" ]]; then
    exec swift test "$@" -Xswiftc -load-plugin-library -Xswiftc "$plugin"
  fi
fi
exec swift test "$@"
