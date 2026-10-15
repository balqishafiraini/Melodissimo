#!/bin/bash
# Usage: compare.sh <baselineDir> <newDir> [heatDir]
# For every screenshot in <newDir> prints how much of it differs from the same file in <baselineDir>
# (percent of pixels, status bar ignored), largest first. iPad screens must stay near 0 (animation noise only);
# a value above about 1.5 means something moved. Heat maps (differences in red) go to <heatDir> if given.
# Needs the helper built once: swiftc -O Scripts/iphone/imgdiff.swift -o "$IMGDIFF" (default /tmp/imgdiff).
set -euo pipefail
tool="${IMGDIFF:-/tmp/imgdiff}"
base="$1"; new="$2"; heat="${3:-}"
[ -n "$heat" ] && mkdir -p "$heat"
for file in "$new"/*.png; do
    name="$(basename "$file" .png)"
    [ -f "$base/$name.png" ] || { echo "-- $name (no baseline)"; continue; }
    if [ -n "$heat" ]; then pct="$("$tool" "$base/$name.png" "$file" "$heat/$name.png")"; else pct="$("$tool" "$base/$name.png" "$file")"; fi
    echo "$pct $name"
done | sort -rn
