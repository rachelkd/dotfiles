#!/bin/bash

sketchybar --add item aerospace_mode left \
    --subscribe aerospace_mode aerospace_mode_change \
    --set aerospace_mode icon="" \
    script="$CONFIG_DIR/plugins/aerospace_mode.sh" \
    icon.color="$BACKGROUND" \
    icon.padding_left=4 \
    drawing=off

# Build the monitor table once now; every later lookup reads the cache instead of
# launching osascript, which costs ~150ms a time.
"$CONFIG_DIR/helpers/monitor_map.sh" --rebuild

# display= is deliberately not set here. The first repaint assigns each item to the
# right display, and it has to do that on every display change anyway.
#
# Only mouse events are per-item: workspace changes are handled in one pass by
# spaces_watcher below, because subscribing all N items to one event makes SketchyBar
# fork this script N times per switch.
args=()
for sid in $(aerospace list-workspaces --all); do
    args+=(--add item space."$sid" left
        --subscribe space."$sid" mouse.entered mouse.exited
        --set space."$sid"
        padding_right=0
        icon="$sid"
        label.padding_right=7
        icon.padding_left=7
        icon.padding_right=7
        background.drawing=on
        label.font="sketchybar-app-font:Regular:13.0"
        background.color="$BACKGROUND"
        icon.color="$ACCENT_COLOR_2"
        label.color="$ACCENT_COLOR_2"
        background.corner_radius=5
        background.border_color="$ACCENT_COLOR_2"
        label.drawing=on
        click_script="aerospace workspace $sid"
        script="$CONFIG_DIR/plugins/aerospace.sh $sid")
done
sketchybar "${args[@]}"

# Hidden driver for SketchyBar's own events only. Workspace switches arrive over the
# aerospace subscribe socket instead (see helpers/aerospace_subscriber.sh), which
# avoids the fork-per-switch the old callback needed.
sketchybar --add item spaces_watcher left \
    --set spaces_watcher drawing=off \
    updates=on \
    script="$CONFIG_DIR/plugins/aerospace_all.sh" \
    --subscribe spaces_watcher display_change display_added_or_removed system_woke

sketchybar --add item space_separator left \
    --set space_separator icon="" \
    icon.font="JetBrainsMono Nerd Font:ExtraBold:14.0" \
    icon.color="$BACKGROUND" \
    icon.padding_left=4 \
    icon.padding_right=7 \
    label.drawing=off \
    background.drawing=off
