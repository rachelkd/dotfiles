#!/bin/bash

# Sourcing exposes __icon_map as a function, which is the usage the
# sketchybar-app-font maintainer intends; the alternative is forking icon_map.sh
# (1391 lines of bash to parse) once per app lookup.
if [ "$SENDER" = "front_app_switched" ]; then
    source "$CONFIG_DIR/plugins/icon_map.sh" "" >/dev/null
    __icon_map "$INFO"
    sketchybar --set "$NAME" label="$INFO" icon="$icon_result"
fi
