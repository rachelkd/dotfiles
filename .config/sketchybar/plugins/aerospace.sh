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

case "$SENDER" in
    mouse.entered)
        sketchybar --set "$NAME" \
            background.drawing=on \
            label.color="$HIGHLIGHT_MED" \
            icon.color="$HIGHLIGHT_MED" \
            background.border_color="$TRANSPARENT" \
            background.color="$TRANSPARENT"
        ;;
    mouse.exited)
        sketchybar --set "$NAME" \
            background.drawing=off \
            label.color="$BACKGROUND" \
            icon.color="$BACKGROUND" \
            background.color="$TRANSPARENT" \
            background.border_color="$TRANSPARENT"
        ;;
esac
