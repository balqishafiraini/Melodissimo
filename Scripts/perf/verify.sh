#!/bin/bash
# Usage: verify.sh [phone-tests]
# STABILITY_PLAN §3.2: iPhone 15 Pro build + iPad Pro 13-inch (M5) tests (+ iPhone 15 Pro tests with "phone-tests").
# Simulators are addressed by UDID (names like "iPhone 15 Pro" exist on several runtimes), the ones in
# Scripts/iphone/devices.txt. Prints errors and failed tests, then one "== <step>: OK|FAILED" line per step.
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$root"
phone=82912AB1-0987-41D0-B945-AC8F57DC62EC
ipad=CD79142D-F647-47A8-A0CC-9C31FAC72E73
log="$(mktemp -t verify)"

run() { # name, args...
    local name="$1"; shift
    if xcodebuild -project Melodissimo.xcodeproj -scheme Melodissimo "$@" -quiet >"$log" 2>&1; then
        echo "== $name: OK"
    else
        grep -E "error:|failed|\*\* " "$log" | sort -u | head -40
        echo "== $name: FAILED"
    fi
    grep -E "warning:" "$log" | grep -v "NavigationLink\|AccentColor" | sort -u | head -10
}

run "build iPhone 15 Pro" -destination "id=$phone" build
run "tests iPad Pro 13" -destination "id=$ipad" test
if [ "${1:-}" = "phone-tests" ]; then run "tests iPhone 15 Pro" -destination "id=$phone" test; fi
