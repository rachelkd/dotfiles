#!/bin/bash

export BAR_HEIGHT=32

bar=(
    position=top
    height="$BAR_HEIGHT"
    margin=0
    y_offset=0
    corner_radius=0
    blur_radius=0
    topmost=window
    color="$BAR_COLOR"
)

sketchybar --bar "${bar[@]}"
