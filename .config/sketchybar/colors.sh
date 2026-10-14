#!/bin/bash

export WHITE=0xffffffff

export TRANSPARENT=0x00000000

# -- Ghostty's active theme --
# Colors come from Ghostty's theme for the current light/dark mode (~/.config/ghostty/palette.sh).
# Plugins source this file on every event, so the palette is cached; sketchybarrc refreshes it on
# each (re)load, including a light/dark switch.
GHOSTTY_PALETTE_CACHE="${TMPDIR:-/tmp}/sketchybar_ghostty_palette"
if [ -n "$GHOSTTY_PALETTE_REFRESH" ] || [ ! -s "$GHOSTTY_PALETTE_CACHE" ]; then
  "$HOME/.config/ghostty/palette.sh" >"$GHOSTTY_PALETTE_CACHE.tmp" &&
    mv "$GHOSTTY_PALETTE_CACHE.tmp" "$GHOSTTY_PALETTE_CACHE"
fi
source "$GHOSTTY_PALETTE_CACHE"
export BAR_COLOR=0x00$GHOSTTY_BG
export ITEM_BG_COLOR=0xff$GHOSTTY_BG
export ACCENT_COLOR=0xff$GHOSTTY_13   # bright magenta
export ACCENT_COLOR_2=0xff$GHOSTTY_9  # bright red
export ACCENT_COLOR_3=0xff$GHOSTTY_12 # bright blue
export ACCENT_COLOR_4=0xff$GHOSTTY_1  # red
export TEXT_COLOR=0xff$GHOSTTY_FG
export MUTED=0xff$GHOSTTY_7         # white
export HIGHLIGHT_LOW=0xff$GHOSTTY_8 # bright black
export HIGHLIGHT_MED=0xff$GHOSTTY_SELECTION
export OVERLAY_COLOR=0xff$GHOSTTY_8 # bright black (temporary panels)
export BACKGROUND=0xff$GHOSTTY_BG
