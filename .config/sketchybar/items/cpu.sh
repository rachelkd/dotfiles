#!/bin/bash

sketchybar --add item cpu right \
    --set cpu update_freq=2 \
    icon=􀧓 \
    padding_left=0 \
    script="$PLUGIN_DIR/cpu.sh"

status_bracket=(
    background.color="$BACKGROUND"
    background.border_color="$ACCENT_COLOR"
)

sketchybar --add bracket status volume battery cpu \
    --set status "${status_bracket[@]}"
