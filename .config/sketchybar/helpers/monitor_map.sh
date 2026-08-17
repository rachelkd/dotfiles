#!/bin/bash
# Maps aerospace's monitor-id to sketchybar's display=N (its `arrangement-id`).
#
# Neither frame geometry nor the NSScreen index reliably lines up between
# aerospace and sketchybar (stacked displays share an X; identical monitors
# share a size). The one identifier both tools agree on is the CGDirectDisplayID:
#
#   aerospace monitor-id
#     -> NSScreen index          (aerospace: monitor-appkit-nsscreen-screens-id)
#     -> CGDirectDisplayID        (bridged via NSScreen.deviceDescription)
#     -> sketchybar arrangement-id (sketchybar: DirectDisplayID -> arrangement-id)
#
# This is correct for any layout -- side-by-side, stacked, or duplicate panels.
#
# The NSScreen bridge needs `osascript -l JavaScript`, and launching the JXA
# interpreter costs ~150ms -- an order of magnitude more than every other call in
# the workspace-switch path combined. So the whole table is resolved once into a
# cache file and only rebuilt when the display layout actually changes.
#
# Usage: monitor_map.sh <aerospace-monitor-id>   look up one id (reads cache)
#        monitor_map.sh --rebuild                recompute the cache
#        monitor_map.sh --print                  dump the cache

CACHE="${TMPDIR:-/tmp}/sketchybar_monitor_map"

rebuild() {
    # Every NSScreen's CGDirectDisplayID, in NSScreen order, in ONE osascript launch.
    local ddids sb_displays
    ddids=$(osascript -l JavaScript -e '
        ObjC.import("AppKit");
        const screens = $.NSScreen.screens;
        const out = [];
        for (let i = 0; i < screens.count; i++) {
            out.push(screens.objectAtIndex(i)
                .deviceDescription.objectForKey("NSScreenNumber").intValue);
        }
        out.join(" ");
    ' 2>/dev/null)

    # The CGDirectDisplayID -> arrangement-id table is passed as a FILE, not with
    # -v: macOS awk rejects a newline inside a -v value ("newline in string"), which
    # aborts the whole program. With one display the value has no newline, so that
    # failure only appears once a second monitor is connected -- and because the
    # write below is guarded, it silently kept a stale all-displays-are-1 map.
    # ddids stays in -v because it is a single space-separated line.
    awk -v ddids="$ddids" '
        BEGIN { n = split(ddids, d, " ") }
        NR == FNR { arr[$1] = $2; next }          # first file: ddid -> arrangement
        {                                          # second file: aerospace monitors
            ddid = ($2 >= 1 && $2 <= n) ? d[$2] : ""
            print $1, (ddid in arr ? arr[ddid] : 1)
        }
    ' \
        <(sketchybar --query displays 2>/dev/null \
            | jq -r '.[] | "\(.DirectDisplayID) \(.["arrangement-id"])"') \
        <(aerospace list-monitors --format '%{monitor-id} %{monitor-appkit-nsscreen-screens-id}' 2>/dev/null) \
        > "$CACHE.tmp" 2>/dev/null

    # A structural failure must not masquerade as a working map, so complain if the
    # result does not cover every monitor. Stderr lands in the sketchybar log.
    want=$(aerospace list-monitors --count 2>/dev/null)
    got=$(grep -c . "$CACHE.tmp" 2>/dev/null)
    if [ -n "$want" ] && [ "$want" != "$got" ]; then
        echo "monitor_map: mapped $got of $want monitors" >&2
    fi

    # Only publish a non-empty table, so a transient failure keeps the last good map.
    if [ -s "$CACHE.tmp" ]; then
        mv "$CACHE.tmp" "$CACHE"
    else
        rm -f "$CACHE.tmp"
    fi
}

case "$1" in
    --rebuild) rebuild; exit 0 ;;
    --print) cat "$CACHE" 2>/dev/null; exit 0 ;;
    "") echo 1; exit 0 ;;
esac

[ -f "$CACHE" ] || rebuild

MAPPED=$(awk -v id="$1" '$1 == id { print $2; exit }' "$CACHE" 2>/dev/null)
echo "${MAPPED:-1}"
