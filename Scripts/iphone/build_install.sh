#!/bin/bash
# Usage: build_install.sh <udid> [<udid> ...]
# Builds the DEBUG app once for the simulator SDK and installs it on every given device.
# DD sets the derived-data folder (default /tmp/melodissimo-dd).
set -euo pipefail

root="$(cd "$(dirname "$0")/../.." && pwd)"
dd="${DD:-/tmp/melodissimo-dd}"

xcodebuild -project "$root/Melodissimo.xcodeproj" -scheme Melodissimo \
    -destination 'generic/platform=iOS Simulator' -derivedDataPath "$dd" build -quiet
app="$dd/Build/Products/Debug-iphonesimulator/Melodissimo.app"

for udid in "$@"; do
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || xcrun simctl boot "$udid" >/dev/null 2>&1 || true
    xcrun simctl install "$udid" "$app"
    echo "installed on $udid"
done
