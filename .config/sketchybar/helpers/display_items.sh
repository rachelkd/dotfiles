#!/bin/bash
# Gives each display its own copy of aerospace_mode.1 and space_separator.1, so the
# repaint can color each for its own bar. Runs at load and when displays change. A
# copy whose display goes away is parked off-screen until it comes back.

for did in $(sketchybar --query displays | jq -r '.[]["arrangement-id"]'); do
    sketchybar --query "space_separator.$did" >/dev/null 2>&1 && continue
    sketchybar --clone "aerospace_mode.$did" aerospace_mode.1 after \
        --set "aerospace_mode.$did" display="$did" \
        --clone "space_separator.$did" space_separator.1 after \
        --set "space_separator.$did" display="$did"
done
