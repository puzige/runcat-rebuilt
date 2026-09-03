#!/bin/bash

# Reproducible acceptance gate for the Classic preservation build.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$REPO_ROOT/RunCat.app"

"$REPO_ROOT/scripts/build.sh"

codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist" >/dev/null
test -x "$APP/Contents/MacOS/RunCat"
test -d "$APP/Contents/Resources/RunCat_SystemInfoKit.bundle"
test -f "$APP/Contents/Resources/en.lproj/Dashboard.strings"
test -f "$APP/Contents/Resources/en.lproj/GeneralSettings.strings"
test -f "$APP/Contents/Resources/en.lproj/RunnersStore.strings"
test -f "$APP/Contents/Resources/runners/cat/cat-page-0@1x.png"
test -f "$APP/Contents/Resources/runners/cat-sleep/cat-sleep@1x.png"
test -f "$APP/Contents/Resources/self-made@2x.png"

runner_frame_count="$(find "$APP/Contents/Resources/runners" -type f -name '*.png' | wc -l | tr -d ' ')"
if [ "$runner_frame_count" -lt 500 ]; then
    echo "error: expected at least 500 preserved runner frames, found $runner_frame_count" >&2
    exit 1
fi

# Validate the exact resource names used by RunnerCatalog.  A raw PNG count is
# not sufficient: the app once shipped all files but looked them up as
# "page-0" instead of "cat-page-0", leaving every picker thumbnail blank.
"$APP/Contents/MacOS/RunCat" --verify-runner-assets
"$APP/Contents/MacOS/RunCat" --verify-runner-speed
"$APP/Contents/MacOS/RunCat" --verify-live-monitor
"$APP/Contents/MacOS/RunCat" --verify-monitor-toggles
"$APP/Contents/MacOS/RunCat" --verify-battery-layout
"$APP/Contents/MacOS/RunCat" --verify-project-links

# The visual preview starts SystemInfoKit immediately, so keeping it alive
# catches the resource-bundle trap that affected the v0.2.0 release.  GitHub's
# hosted runner has no reliable interactive WindowServer; CI still exercises
# all static bundle gates above.
if [ "${CI:-false}" != "true" ]; then
    "$APP/Contents/MacOS/RunCat" --preview-dashboard >/tmp/runcat-rebuilt-smoke.log 2>&1 &
    smoke_pid=$!
    cleanup() {
        kill "$smoke_pid" 2>/dev/null || true
        wait "$smoke_pid" 2>/dev/null || true
    }
    trap cleanup EXIT
    sleep 5
    if ! kill -0 "$smoke_pid" 2>/dev/null; then
        wait "$smoke_pid"
        echo "error: dashboard runtime smoke test exited early" >&2
        exit 1
    fi
    cleanup
    trap - EXIT
fi

echo "Classic build verification passed ($runner_frame_count runner images)."
