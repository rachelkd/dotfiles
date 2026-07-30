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
# This is correct for any layout — side-by-side, stacked, or duplicate panels.
#
# Usage: monitor_map.sh <aerospace-monitor-id>
#        Prints the corresponding sketchybar arrangement-id, or "1" on failure.

AEROSPACE_ID="$1"
[ -z "$AEROSPACE_ID" ] && { echo 1; exit 0; }

# aerospace monitor-id -> NSScreen index (1-based)
NS_INDEX=$(aerospace list-monitors --format '%{monitor-id} %{monitor-appkit-nsscreen-screens-id}' 2>/dev/null \
    | awk -v id="$AEROSPACE_ID" '$1 == id { print $2; exit }')

# NSScreen index -> CGDirectDisplayID
DDID=$(osascript -l JavaScript -e '
    ObjC.import("AppKit");
    const screens = $.NSScreen.screens;
    const args = $.NSProcessInfo.processInfo.arguments;
    const i = parseInt(args.objectAtIndex(args.count - 1).js, 10) - 1;
    (i >= 0 && i < screens.count)
        ? screens.objectAtIndex(i).deviceDescription.objectForKey("NSScreenNumber").intValue
        : "";
' "$NS_INDEX" 2>/dev/null)

# CGDirectDisplayID -> sketchybar arrangement-id
MAPPED=$(sketchybar --query displays 2>/dev/null \
    | jq -r --argjson d "${DDID:-0}" '.[] | select(.DirectDisplayID == $d) | .["arrangement-id"]')

[ -z "$MAPPED" ] && MAPPED=1
echo "$MAPPED"
