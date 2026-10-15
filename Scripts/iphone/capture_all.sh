#!/bin/bash
# Usage: [DEVICES="se 15pro"] [SEED=1] capture_all.sh <outroot> [name ...]
# Runs capture.sh on every device in devices.txt (or the short names in $DEVICES) in parallel and saves
# <outroot>/<short-name>/<name>.png. Install the app first with build_install.sh.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
outroot="$1"
shift

pids=()
while IFS='|' read -r short _ _ udid mode; do
    short="$(echo "$short" | xargs)"
    udid="$(echo "$udid" | xargs)"
    mode="$(echo "${mode:-rotate}" | xargs)"
    case "$short" in ''|\#*) continue ;; esac
    if [ -n "${DEVICES:-}" ] && ! [[ " $DEVICES " == *" $short "* ]]; then continue; fi
    xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
    SHOT_MODE="$mode" "$here/capture.sh" "$udid" "$outroot/$short" "$@" > "$outroot.$short.log" 2>&1 &
    pids+=($!)
done < "$here/devices.txt"

status=0
for pid in "${pids[@]}"; do wait "$pid" || status=1; done
echo "done (status $status); logs: $outroot.<device>.log"
exit $status
