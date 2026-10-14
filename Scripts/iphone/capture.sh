#!/bin/bash
# Usage: capture.sh <udid> <outdir> [name ...]
# Launches the installed DEBUG app once per screen name and saves <outdir>/<name>.png (landscape, 1200 px wide).
# With no names it captures the default list below.
#
# Environment:
#   SEED=1      fill the mid-game profile (-qaSeed YES); without it the profile is whatever the simulator holds
#   LANG_ID=1   render Indonesian instead of English
#   WAIT=<s>    fixed wait after the first non-blank frame (default 3)
#   EXTRA=...   more launch arguments, e.g. EXTRA="-qaSong halo-halo-bandung"
#   BUNDLE_ID   defaults to com.balqishafiraini.Melodissimo
#
# Names: any `-qaRoute` name (see Views/Common/QARoutes.swift), `dashboard`, `splash`,
#        `onboard-<first|tutorial|preplay|preplayScore|onboardPostplay|postplay|postplayScore>`,
#        `overlay-<story|storyBoss|certificate>`, `cover-<calibration|micCalibration>`.
set -euo pipefail

udid="$1"
outdir="$2"
shift 2
here="$(cd "$(dirname "$0")" && pwd)"
bundle="${BUNDLE_ID:-com.balqishafiraini.Melodissimo}"
wait_seconds="${WAIT:-3}"

default_names=(
    dashboard freePlay learnHub campaignMap shop settings achievements help
    notationLearn songRepositoryLearn songRepositoryQuiz notationLevelMenu postplay chartRecorder
    songLearn stageSetup stageListen stagePractice stagePerform stageBoss stageSolemn
    battle battleBoss echo rush classic result3 result0
    onboard-first onboard-tutorial onboard-preplay onboard-preplayScore
    onboard-onboardPostplay onboard-postplay onboard-postplayScore
    overlay-story overlay-storyBoss overlay-certificate cover-calibration cover-micCalibration
)
if [ "$#" -gt 0 ]; then names=("$@"); else names=("${default_names[@]}"); fi

if [ "${LANG_ID:-0}" = "1" ]; then
    language_args=(-AppleLanguages "(id)" -AppleLocale id_ID)
else
    language_args=(-AppleLanguages "(en)" -AppleLocale en_US)
fi

raw="$(mktemp -t melodissimo-raw).png"
trap 'rm -f "$raw"' EXIT

# True when the frame is blank: a screenshot with (almost) no detail compresses to a few KB.
is_blank() { [ "$(stat -f%z "$1")" -lt 30000 ]; }

mkdir -p "$outdir"
for name in "${names[@]}"; do
    args=(-isPreplayDone YES)
    case "$name" in
        splash) args=(-isPreplayDone YES) ;;
        onboard-*) args=(-qaSkipSplash YES -qaOnboarding "${name#onboard-}") ;;
        overlay-*) args+=(-qaSkipSplash YES -qaRoute campaignMap -qaOverlay "${name#overlay-}") ;;
        cover-*) args+=(-qaSkipSplash YES -qaRoute settings -qaCover "${name#cover-}") ;;
        *) args+=(-qaSkipSplash YES -qaRoute "$name") ;;
    esac
    if [ "${SEED:-0}" = "1" ]; then args+=(-qaSeed YES); fi
    # shellcheck disable=SC2206
    args+=(${EXTRA:-})

    xcrun simctl terminate "$udid" "$bundle" >/dev/null 2>&1 || true
    container="$(xcrun simctl get_app_container "$udid" "$bundle" data)"
    rm -f "$container/Documents/qa-ready.txt"
    xcrun simctl launch "$udid" "$bundle" "${language_args[@]}" "${args[@]}" >/dev/null

    # The DEBUG app writes qa-ready.txt once the requested screen is up (QARoutes.markReady). `splash` and
    # `dashboard` with no route have no such signal, so those fall back to the first non-blank frame.
    started=$SECONDS
    if [ "$name" = "splash" ]; then
        until xcrun simctl io "$udid" screenshot --type=png "$raw" >/dev/null 2>&1 && ! is_blank "$raw"; do
            if [ $((SECONDS - started)) -ge 60 ]; then echo "warning: $name still blank after 60 s" >&2; break; fi
            sleep 1
        done
    else
        until [ -f "$container/Documents/qa-ready.txt" ]; do
            if [ $((SECONDS - started)) -ge 90 ]; then echo "warning: $name never reported ready (90 s)" >&2; break; fi
            sleep 1
        done
    fi
    # Let animations, images and the screen's own entrance settle.
    sleep "$wait_seconds"

    "$here/shot.sh" "$udid" "$outdir/$name.png"
    echo "captured $name"
done
