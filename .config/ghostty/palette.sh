#!/usr/bin/env bash
# Prints the colors of Ghostty's active theme as shell assignments, so apps that need exact
# colors (SketchyBar's colors.sh) use Ghostty's palette instead of hex copies:
#   GHOSTTY_0 … GHOSTTY_15, GHOSTTY_BG, GHOSTTY_FG, GHOSTTY_SELECTION   (rrggbb, no "#")
# Pass "light" or "dark" to pick that side of `theme = light:…,dark:…`; by default it follows
# the macOS appearance.
set -euo pipefail

if [[ -n ${1:-} ]]; then
  mode=$1
elif [[ $(defaults read -g AppleInterfaceStyle 2>/dev/null) == Dark ]]; then
  mode=dark
else
  mode=light
fi

theme=$(sed -nE 's/^[[:space:]]*theme[[:space:]]*=[[:space:]]*//p' "$HOME/.config/ghostty/config" | tail -1)
if [[ $theme == *:* ]]; then
  theme=$(tr ',' '\n' <<<"$theme" | sed -nE "s/^[[:space:]]*$mode:[[:space:]]*//p")
fi

# A user theme, else one bundled with Ghostty; sed fails if neither exists.
file="$HOME/.config/ghostty/themes/$theme"
[[ -f $file ]] || file="/Applications/Ghostty.app/Contents/Resources/ghostty/themes/$theme"

sed -nE \
  -e 's/^palette *= *([0-9]+) *= *#?([0-9a-fA-F]{6}).*/GHOSTTY_\1=\2/p' \
  -e 's/^background *= *#?([0-9a-fA-F]{6}).*/GHOSTTY_BG=\1/p' \
  -e 's/^foreground *= *#?([0-9a-fA-F]{6}).*/GHOSTTY_FG=\1/p' \
  -e 's/^selection-background *= *#?([0-9a-fA-F]{6}).*/GHOSTTY_SELECTION=\1/p' \
  "$file"
