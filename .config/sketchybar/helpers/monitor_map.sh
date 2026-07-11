#!/bin/bash
# Maps aerospace's spatial monitor-id (1=leftmost, ascending by X) to
# sketchybar's display=N (its `arrangement-id`).
#
# Usage: monitor_map.sh <aerospace-monitor-id>
#        Prints the corresponding sketchybar arrangement-id, or "1" on failure.

AEROSPACE_ID="$1"
[ -z "$AEROSPACE_ID" ] && { echo 1; exit 0; }

MAPPED=$(sketchybar --query displays 2>/dev/null \
    | jq -r --argjson i "$AEROSPACE_ID" \
        'sort_by(.frame.x) | .[$i-1]["arrangement-id"] // empty')

[ -z "$MAPPED" ] && MAPPED=1
echo "$MAPPED"
