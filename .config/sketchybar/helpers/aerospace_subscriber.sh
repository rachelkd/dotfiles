#!/bin/bash
# Long-lived AeroSpace event reader (aerospace subscribe, 0.21.0-Beta+).
#
# Replaces exec-on-workspace-change, which forked /bin/bash and then
# `sketchybar --trigger` on every switch, which in turn forked the repaint script.
# This loop is already running, so a switch costs two aerospace queries and one
# sketchybar message. focused-workspace-changed also fires exactly once per switch,
# unlike the callback, which double-fired on some transitions (SketchyBar #726).
#
# Uses a pipeline, NOT `while ... done < <(cmd)`. Process substitution inside a loop
# that runs for hours leaks its subshells; an earlier version of this script
# accumulated several hundred copies of itself that way. The lock is the backstop:
# however many copies get started, only one runs.

LOCKDIR="${TMPDIR:-/tmp}/sketchybar_aerospace_subscriber.lock"

if ! mkdir "$LOCKDIR" 2>/dev/null; then
    owner=$(cat "$LOCKDIR/pid" 2>/dev/null)
    if [ -n "$owner" ] && kill -0 "$owner" 2>/dev/null; then
        exit 0 # a live instance already owns the socket
    fi
    rm -f "$LOCKDIR/pid"      # stale lock from a killed instance
    rmdir "$LOCKDIR" 2>/dev/null
    mkdir "$LOCKDIR" 2>/dev/null || exit 0
fi
echo $$ > "$LOCKDIR/pid"

# Release only if we still own it: a dying old instance must not delete the lock a
# newly started one has just taken. There is no EXIT trap because bash 3.2 has no
# BASHPID, so the pipeline's subshell shares $$ and would release on its own exit.
# A lock left behind is fine -- the stale-owner check above reclaims it.
trap '[ "$(cat "$LOCKDIR/pid" 2>/dev/null)" = "$$" ] && { rm -f "$LOCKDIR/pid"; rmdir "$LOCKDIR"; }; exit 0' INT TERM

source "$CONFIG_DIR/colors.sh"
source "$CONFIG_DIR/helpers/spaces_render.sh"

# Pulls a string value out of one JSON line with shell builtins only; a jq fork per
# event would undo the point of this loop.
json_str() {
    local s="$1" k="\"$2\":\"" rest
    case "$s" in
        *"$k"*) rest="${s#*"$k"}"; json_str_val="${rest%%\"*}" ;;
        *) json_str_val="" ;;
    esac
}

current_focus=""

handle_event() {
    local line="$1" ev ws mode

    json_str "$line" _event; ev="$json_str_val"
    case "$ev" in
        # focused-monitor-changed matters as much as the workspace one: moving a
        # workspace between monitors (move-workspace-to-monitor) keeps the same
        # workspace name, so it fires ONLY focused-monitor-changed. Without it the
        # item stayed on the old monitor's bar. Both carry `workspace`, and both need
        # the same repaint, since display= is decided per item there.
        focused-workspace-changed | focused-monitor-changed)
            json_str "$line" workspace; ws="$json_str_val"
            [ -z "$ws" ] && return
            current_focus="$ws"
            reconcile_spaces "$ws"
            ;;
        window-detected)
            # Lets icons refresh when a window appears, which a workspace-change
            # callback could never see.
            [ -z "$current_focus" ] &&
                current_focus=$(aerospace list-workspaces --focused --format '%{workspace}')
            reconcile_spaces "$current_focus"
            ;;
        mode-changed)
            json_str "$line" mode; mode="$json_str_val"
            if [ "$mode" = "main" ]; then
                sketchybar --set aerospace_mode drawing=off
            else
                sketchybar --set aerospace_mode drawing=on
            fi
            ;;
    esac
}

# The outer loop reconnects if AeroSpace restarts and closes the socket. A plain
# blocking read is used rather than `read -t`: bash 3.2 returns 1 for both a timeout
# and EOF, so a quiet stream could not be told apart from AeroSpace exiting.
while true; do
    aerospace subscribe focused-workspace-changed focused-monitor-changed \
        window-detected mode-changed 2>/dev/null |
        while IFS= read -r line; do
            handle_event "$line"
        done
    current_focus=""
    sleep 1
done
