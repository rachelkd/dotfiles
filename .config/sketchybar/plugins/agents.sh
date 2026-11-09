#!/bin/bash
#
# One dot per Rex pane whose agent is blocked (icon, red) or working (label, yellow),
# from the "working blocked" counts that ~/.config/rex/agents.lua writes.

read -r WORKING BLOCKED 2>/dev/null < "${TMPDIR:-/tmp}/sketchybar_rex_agents"

dots() { printf '%*s' "${1:-0}" '' | sed 's/ /●/g'; }
on() { (( ${1:-0} > 0 )) && echo on || echo off; }

sketchybar --set "$NAME" drawing="$(on $((WORKING + BLOCKED)))" \
    icon="$(dots "$BLOCKED")" icon.drawing="$(on "$BLOCKED")" \
    label="$(dots "$WORKING")" label.drawing="$(on "$WORKING")"
