#!/bin/bash
# Repaints every workspace item in a single sketchybar message.
#
# This is a sourceable function rather than a script because aerospace_subscriber.sh
# is long-lived and would otherwise fork a shell and re-parse the icon map on every
# event. Requires colors.sh to be sourced by the caller.
#
# Written for bash 3.2 (stock macOS): no associative arrays.

# __icon_map as a function, so mapping an app name costs no process.
source "$CONFIG_DIR/helpers/icon_map.sh"

FOCUSED_CACHE="${TMPDIR:-/tmp}/sketchybar_focused_workspace"
MONITOR_MAP_CACHE="${TMPDIR:-/tmp}/sketchybar_monitor_map"
# Written by scripts/bar_blend: the displays whose bar is dark behind the workspaces.
DARK_DISPLAYS="${TMPDIR:-/tmp}/sketchybar_dark_displays"
SPACE_TEXT_CACHE="${TMPDIR:-/tmp}/sketchybar_space_text"

rebuild_monitor_map() { "$CONFIG_DIR/helpers/monitor_map.sh" --rebuild; }

# reconcile_spaces <focused-workspace>
reconcile_spaces() {
    local focused="$1" monitors windows workspaces ws mon w app icons display ddid dark text texts focused_text args

    [ -f "$MONITOR_MAP_CACHE" ] || rebuild_monitor_map
    monitors=$(<"$MONITOR_MAP_CACHE")
    [ -f "$DARK_DISPLAYS" ] && dark=" $(<"$DARK_DISPLAYS") "

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

        display=1 ddid=""
        while read -r aid sbid id; do
            [ "$aid" = "$mon" ] && { display="$sbid" ddid="$id"; break; }
        done <<< "$monitors"

        # Items without a box get a light color on a dark bar.
        text="$BACKGROUND"
        case "$dark" in *" ${ddid:-none} "*) text="$BRIGHT_WHITE" ;; esac
        texts="$texts$ws $text"$'\n'

        if [ "$ws" = "$focused" ]; then
            focused_text="$text"
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
                label.color="$text" icon.color="$text"
                background.drawing=off background.color="$TRANSPARENT"
                background.border_color="$TRANSPARENT")
        fi
    done <<< "$workspaces"
    args+=(--set space_separator icon.color="${focused_text:-$BACKGROUND}"
        --set aerospace_mode icon.color="${focused_text:-$BACKGROUND}")

    # Read by the hover script, so it needs no IPC of its own.
    printf '%s' "$focused" > "$FOCUSED_CACHE"
    printf '%s' "$texts" > "$SPACE_TEXT_CACHE"

    sketchybar "${args[@]}"
}
