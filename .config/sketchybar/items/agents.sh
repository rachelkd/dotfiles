#!/bin/bash

sketchybar --add item agents right \
           --set agents drawing=off \
                        icon.font="Iosevka:Medium:13.0" \
                        icon.color="$ACCENT_COLOR_4" \
                        label.color="$ACCENT_COLOR_5" \
                        script="$PLUGIN_DIR/agents.sh" \
           --subscribe agents rex_agents_changed
