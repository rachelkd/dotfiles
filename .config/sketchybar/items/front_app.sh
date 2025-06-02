#!/bin/bash

sketchybar --add item front_app left \
    --set front_app background.color="$BACKGROUND" \
    icon.color="$ACCENT_COLOR_2" \
    icon.font="sketchybar-app-font:Regular:12.0" \
    label.color="$ACCENT_COLOR_2" \
    label.padding_right=7 \
    icon.padding_left=7 \
    icon.padding_right=7 \
    background.border_color="$ACCENT_COLOR_2" \
    script="$PLUGIN_DIR/front_app.sh" \
    --subscribe front_app front_app_switched
