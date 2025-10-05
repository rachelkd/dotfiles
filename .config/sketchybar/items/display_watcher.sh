#!/bin/bash

sketchybar --add item display_watcher left \
    --set display_watcher script="sketchybar --reload" \
    --subscribe display_watcher display_added_or_removed \
    --set display_watcher drawing=off
