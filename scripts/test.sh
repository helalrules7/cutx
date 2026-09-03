#!/usr/bin/env bash
# Runs the unit tests.
#
# On a machine with only Command Line Tools installed (no Xcode), plain
# `swift test` cannot find the swift-testing macro plugin or Testing.framework.
# These flags point at where the CLT actually keeps them. They are added here
# rather than in Package.swift so the package stays portable — on a machine with
# full Xcode, plain `swift test` works and these paths simply do not exist.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

CLT="/Library/Developer/CommandLineTools"
PLUGIN="$CLT/usr/lib/swift/host/plugins/testing/libTestingMacros.dylib"

if [[ -f "$PLUGIN" ]]; then
    exec swift test \
        -Xswiftc -load-plugin-library -Xswiftc "$PLUGIN" \
        -Xlinker -rpath -Xlinker "$CLT/Library/Developer/Frameworks" \
        -Xlinker -rpath -Xlinker "$CLT/Library/Developer/usr/lib" \
        "$@"
else
    exec swift test "$@"
fi
