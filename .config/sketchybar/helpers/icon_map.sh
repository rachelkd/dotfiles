#!/bin/bash
# Sourceable: defines __icon_map, which sets $icon_result to the app's glyph.
#
# The map itself is generated from the installed font by gen_icon_map.py (run from
# sketchybarrc). If generation has never succeeded, fall back to the default icon
# rather than leaving __icon_map undefined.

# Keep in sync with DEFAULT_OUTPUT in gen_icon_map.py.
ICON_MAP_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/sketchybar/icon_map.sh"

source "$ICON_MAP_CACHE" 2>/dev/null || __icon_map() { icon_result=":default:"; }
