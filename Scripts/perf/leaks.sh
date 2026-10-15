#!/bin/bash
# Usage: leaks.sh <simulator-udid> <qaRoute> [cycles=10]
# Builds + installs the Debug app, launches it with `-qaRoute <route> -qaCycle <cycles>` (the route is left and
# re-entered <cycles> times, see QARoutes.swift), waits for the app to report "QA cycle done", then runs `leaks`
# and `footprint` on the process. Writes Scripts/perf/out/<route>-<date>.txt and prints one summary line:
#   leaks: N (B bytes), footprint: X MB
# Extra launch arguments can be passed in EXTRA (e.g. EXTRA="-qaInputMode pianika"). SKIP_BUILD=1 reuses the
# installed build. STACKS=1 turns on malloc stack logging so leaks shows allocation backtraces (inflates footprint). DD sets the derived-data folder (default /tmp/melodissimo-dd).
set -euo pipefail

udid="$1"
route="$2"
cycles="${3:-10}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
bundle="com.balqishafiraini.Melodissimo"
out="$root/Scripts/perf/out"
mkdir -p "$out"
file="$out/$route-$(date +%Y%m%d-%H%M%S).txt"

if [ -z "${SKIP_BUILD:-}" ]; then
    "$root/Scripts/iphone/build_install.sh" "$udid" >/dev/null
fi
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || xcrun simctl boot "$udid" >/dev/null 2>&1 || true
xcrun simctl terminate "$udid" "$bundle" >/dev/null 2>&1 || true

container="$(xcrun simctl get_app_container "$udid" "$bundle" data)"
rm -f "$container/Documents/qa-cycle-done.txt"

# shellcheck disable=SC2086
SIMCTL_CHILD_MallocStackLogging="${STACKS:-0}" xcrun simctl launch "$udid" "$bundle" -AppleLanguages "(en)" -isPreplayDone YES -qaSkipSplash YES -qaSeed YES \
    -qaRoute "$route" -qaCycle "$cycles" ${EXTRA:-} >/dev/null

# Each cycle is ~4.6 s, plus the first push and the final wait.
timeout=$(( cycles * 6 + 30 ))
waited=0
until [ -f "$container/Documents/qa-cycle-done.txt" ]; do
    sleep 1
    waited=$(( waited + 1 ))
    if [ "$waited" -gt "$timeout" ]; then echo "timed out waiting for QA cycle done" >&2; exit 1; fi
done

pid="$(pgrep -f "Devices/$udid/.*Melodissimo.app/Melodissimo" | head -1 || true)"
if [ -z "$pid" ]; then echo "app is not running" >&2; exit 1; fi
sleep 2  # let the last pop settle

{
    echo "== leaks $route x$cycles ($(date))"
    leaks "$pid" || true
    echo
    echo "== footprint"
    footprint "$pid" || true
} > "$file" 2>&1

leak_line="$(grep -E "^Process [0-9]+: [0-9]+ leaks? for [0-9]+ total leaked bytes" "$file" | head -1 || true)"
count="$(echo "$leak_line" | sed -E 's/^Process [0-9]+: ([0-9]+) leaks? for ([0-9]+) total leaked bytes.*/\1/')"
bytes="$(echo "$leak_line" | sed -E 's/^Process [0-9]+: ([0-9]+) leaks? for ([0-9]+) total leaked bytes.*/\2/')"
# The footprint header reads "Melodissimo [123]: 64-bit    Footprint: 57 MB (16384 bytes per page)".
fp="$(grep -E "Footprint: " "$file" | head -1 | sed -E 's/.*Footprint: ([0-9]+ [KMG]B).*/\1/' || true)"
echo "$route x$cycles — leaks: ${count:-?} (${bytes:-?} bytes), footprint: ${fp:-?}  [$file]"
