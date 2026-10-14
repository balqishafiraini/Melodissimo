#!/bin/bash
# Usage: shot.sh <udid> <out.png>
# Takes a simulator screenshot, turns it landscape (home indicator at the bottom) and scales it to 1200 px wide.
#
# `simctl io screenshot` returns the device's portrait framebuffer with the landscape app rotated inside it, and the
# direction depends on which landscape orientation the simulator is in. The app (DEBUG builds) writes its interface
# orientation to Documents/qa-orientation.txt, which is read here. Override with ROT=90|270 if needed.
# SHOT_MODE=letterbox (set by capture_all.sh from devices.txt) is for the iOS 26 iPad simulators, which do not rotate.
set -euo pipefail

udid="$1"
out="$2"
bundle="${BUNDLE_ID:-com.balqishafiraini.Melodissimo}"
tmp="$(mktemp -t melodissimo-shot).png"
trap 'rm -f "$tmp"' EXIT

xcrun simctl io "$udid" screenshot --type=png "$tmp" >/dev/null 2>&1

width=$(sips -g pixelWidth "$tmp" | awk '/pixelWidth/ {print $2}')
height=$(sips -g pixelHeight "$tmp" | awk '/pixelHeight/ {print $2}')

if [ "$height" -gt "$width" ] && [ "${SHOT_MODE:-rotate}" = "letterbox" ]; then
    # iPad on iOS 26 simulators: the portrait framebuffer holds the landscape app upright, scaled to the full
    # width, between two black bars. Cut the bars off.
    content=$(( width * width / height ))
    offset=$(( (height - content) / 2 ))
    sips --cropOffset "$offset" 0 --cropToHeightWidth "$content" "$width" "$tmp" >/dev/null
elif [ "$height" -gt "$width" ]; then
    rot="${ROT:-}"
    if [ -z "$rot" ]; then
        container="$(xcrun simctl get_app_container "$udid" "$bundle" data 2>/dev/null || true)"
        orientation="$(cat "$container/Documents/qa-orientation.txt" 2>/dev/null || true)"
        # Calibrated on 14 Oct 2026 (iPhone 15 Pro, iPad Air): interface orientation landscapeLeft needs a
        # 90° clockwise turn, landscapeRight a 270° one.
        case "$orientation" in
            landscapeRight) rot=270 ;;
            *) rot=90 ;;
        esac
    fi
    sips -r "$rot" "$tmp" >/dev/null
fi

mkdir -p "$(dirname "$out")"
sips --resampleWidth 1200 "$tmp" --out "$out" >/dev/null
