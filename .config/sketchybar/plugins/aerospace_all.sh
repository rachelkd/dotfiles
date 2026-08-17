#!/bin/bash
# Repaint for SketchyBar's own events: display changes, wake from sleep, and the
# forced --update at the end of sketchybarrc. Workspace switches arrive over the
# socket instead, in helpers/aerospace_subscriber.sh.

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/helpers/spaces_render.sh"

# Only these events can renumber displays, and rebuilding costs an osascript launch
# (~150ms), so everything else reads the cached table. display_added_or_removed is
# the one that fires when a monitor is plugged in or unplugged, which is exactly when
# aerospace's monitor ids stop matching the cached mapping.
DISPLAYS_CHANGED=""
case "$SENDER" in
    display_change | display_added_or_removed | system_woke)
        DISPLAYS_CHANGED=1
        rebuild_monitor_map
        ;;
esac

FOCUSED="$FOCUSED_WORKSPACE"
[ -z "$FOCUSED" ] && FOCUSED=$(aerospace list-workspaces --focused --format '%{workspace}')

reconcile_spaces "$FOCUSED"

# NSApplicationDidChangeScreenParametersNotification fires the instant macOS changes
# screen parameters, which is before sketchybar has re-enumerated its displays and
# before aerospace has moved workspaces off a monitor that just went away. So the
# pass above can paint a half-applied arrangement, and on disconnect nothing else
# fires afterwards to correct it -- the bar just stays wrong.
#
# Wait for the two to agree on how many screens exist, then repaint against the
# settled arrangement. Bounded, and it returns as soon as they match.
if [ -n "$DISPLAYS_CHANGED" ]; then
    tries=0
    while [ "$tries" -lt 12 ]; do
        sb_count=$(sketchybar --query displays 2>/dev/null | jq 'length' 2>/dev/null)
        ae_count=$(aerospace list-monitors --count 2>/dev/null)
        [ -n "$sb_count" ] && [ "$sb_count" = "$ae_count" ] && break
        sleep 0.25
        tries=$((tries + 1))
    done

    rebuild_monitor_map
    reconcile_spaces "$(aerospace list-workspaces --focused --format '%{workspace}')"
fi
