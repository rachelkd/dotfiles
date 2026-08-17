#!/bin/bash
# Repaints every workspace item in a single sketchybar message.
#
# This is a sourceable function rather than a script because aerospace_subscriber.sh
# is long-lived and would otherwise fork a shell and re-parse icon_map.sh (1391
# lines) on every event. Requires colors.sh to be sourced by the caller.
#
# Written for bash 3.2 (stock macOS): no associative arrays.

# __icon_map as a function, so mapping an app name costs no process. The explicit ""
# keeps the trailing lookup in that file from seeing our argv.
source "$CONFIG_DIR/plugins/icon_map.sh" "" >/dev/null

FOCUSED_CACHE="${TMPDIR:-/tmp}/sketchybar_focused_workspace"
MONITOR_MAP_CACHE="${TMPDIR:-/tmp}/sketchybar_monitor_map"

rebuild_monitor_map() { "$CONFIG_DIR/helpers/monitor_map.sh" --rebuild; }

# reconcile_spaces <focused-workspace>
reconcile_spaces() {
    local focused="$1" monitors windows workspaces ws mon w app icons display args

    [ -f "$MONITOR_MAP_CACHE" ] || rebuild_monitor_map
    monitors=$(<"$MONITOR_MAP_CACHE")

    # Two queries for the whole bar. Asking per workspace instead would multiply
    # these by the workspace count on every switch.
    windows=$(aerospace list-windows --all --format '%{workspace}%{tab}%{app-name}')
    workspaces=$(aerospace list-workspaces --all --format '%{workspace} %{monitor-id}')

    args=()
    while read -r ws mon; do
        [ -z "$ws" ] && continue

        icons=""
        while IFS=$'\t' read -r w app; do
            [ "$w" = "$ws" ] && { __icon_map "$app"; icons="$icons$icon_result  "; }
        done <<< "$windows"

        display=1
        while read -r aid sbid; do
            [ "$aid" = "$mon" ] && { display="$sbid"; break; }
        done <<< "$monitors"

        if [ "$ws" = "$focused" ]; then
            args+=(--set "space.$ws"
                display="$display" drawing=on label="$icons"
                label.color="$ACCENT_COLOR_2" icon.color="$ACCENT_COLOR_2"
                background.drawing=on background.color="$BACKGROUND"
                background.border_color="$ACCENT_COLOR_2" background.border_width=2)
        elif [ -z "$icons" ]; then
            # Empty and unfocused: hide it, and clear the label so it cannot later
            # reappear showing the icons it had when it still held windows.
            args+=(--set "space.$ws" drawing=off label="")
        else
            args+=(--set "space.$ws"
                display="$display" drawing=on label="$icons"
                label.color="$BACKGROUND" icon.color="$BACKGROUND"
                background.drawing=off background.color="$TRANSPARENT"
                background.border_color="$TRANSPARENT")
        fi
    done <<< "$workspaces"

    # Read by the hover script, so it needs no IPC of its own.
    printf '%s' "$focused" > "$FOCUSED_CACHE"

    sketchybar "${args[@]}"
}
