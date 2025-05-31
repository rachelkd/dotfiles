#!/bin/bash

bar=(
    position=top
    height=32
    margin=0
    y_offset=0
    corner_radius=0
    blur_radius=20
    color="$BAR_COLOR"
)

sketchybar --bar "${bar[@]}"
