#!/bin/bash

sketchybar --add item caffeinate right \
    --set caffeinate script="$PLUGIN_DIR/caffeinate.sh" \
    click_script="$PLUGIN_DIR/caffeinate.sh" \
    icon.font="JetBrainsMono Nerd Font:Bold:15.0" \
    icon= \
    background.drawing=on \
    icon.padding_left=6 \
    icon.padding_right=4 \
    label.padding_left=0 \
    label.padding_right=0