#!/bin/bash

POPUP_OFF='sketchybar --set apple.logo popup.drawing=off'
POPUP_CLICK_SCRIPT='sketchybar --set $NAME popup.drawing=toggle'

apple_logo=(
    icon=
    icon.font="JetBrainsMono Nerd Font:ExtraBold:18.0"
    icon.color="$BACKGROUND"
    padding_right=15
    label.drawing=off
    click_script="$POPUP_CLICK_SCRIPT"
    popup.height=35
)

apple_prefs=(
    icon=
    label="Preferences"
    click_script="open -a 'System Preferences'; $POPUP_OFF"
)

apple_activity=(
    icon=
    label="Activity"
    click_script="open -a 'Activity Monitor'; $POPUP_OFF"
)

apple_lock=(
    icon=
    label="Lock Screen"
    click_script="pmset displaysleepnow; $POPUP_OFF"
)

sketchybar --add item apple.logo left \
    --set apple.logo "${apple_logo[@]}" \
    --set apple.logo popup.background.drawing=on \
    popup.background.color="$ITEM_BG_COLOR" \
    popup.background.corner_radius=5 \
    popup.y_offset=10 \
    \
    --add item apple.prefs popup.apple.logo \
    --set apple.prefs "${apple_prefs[@]}" \
    icon.color="$ACCENT_COLOR_4" \
    label.color="$ACCENT_COLOR_4" \
    \
    --add item apple.activity popup.apple.logo \
    --set apple.activity "${apple_activity[@]}" \
    icon.color="$ACCENT_COLOR_4" \
    label.color="$ACCENT_COLOR_4" \
    \
    --add item apple.lock popup.apple.logo \
    --set apple.lock "${apple_lock[@]}" \
    icon.color="$ACCENT_COLOR_4" \
    label.color="$ACCENT_COLOR_4"
