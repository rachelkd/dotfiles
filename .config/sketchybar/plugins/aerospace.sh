#!/bin/bash
# Hover styling for one workspace item. Runs only for mouse.entered / mouse.exited on
# the item under the cursor, so it stays tiny; workspace contents are repainted
# elsewhere, in one pass (helpers/spaces_render.sh).

source "$CONFIG_DIR/colors.sh"

FOCUSED_CACHE="${TMPDIR:-/tmp}/sketchybar_focused_workspace"

# Written by every repaint, so hover needs no aerospace round-trip.
FOCUSED_WORKSPACE=$(cat "$FOCUSED_CACHE" 2>/dev/null)
[ -z "$FOCUSED_WORKSPACE" ] &&
    FOCUSED_WORKSPACE=$(aerospace list-workspaces --focused --format '%{workspace}')

# The focused item has its own styling; leave it alone.
[ "$1" = "$FOCUSED_WORKSPACE" ] && exit 0

# Every repaint writes the color of each item for its bar. Hover dims it.
TEXT=$(awk -v ws="$1" '$1 == ws { print $2 }' "${TMPDIR:-/tmp}/sketchybar_space_text" 2>/dev/null)
TEXT="${TEXT:-$BACKGROUND}"
HOVER="$HIGHLIGHT_MED"
[ "$TEXT" = "$BRIGHT_WHITE" ] && HOVER="$MUTED"

case "$SENDER" in
    mouse.entered)
        sketchybar --set "$NAME" \
            background.drawing=on \
            label.color="$HOVER" \
            icon.color="$HOVER" \
            background.border_color="$TRANSPARENT" \
            background.color="$TRANSPARENT"
        ;;
    mouse.exited)
        sketchybar --set "$NAME" \
            background.drawing=off \
            label.color="$TEXT" \
            icon.color="$TEXT" \
            background.color="$TRANSPARENT" \
            background.border_color="$TRANSPARENT"
        ;;
esac
