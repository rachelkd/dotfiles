#!/usr/bin/env bash
# Toggle the macOS system appearance between light and dark.
#
# Everything that matters already follows the system appearance, so this one
# flip retints all of them at once:
#   - Ghostty  via `theme = light:Rose Pine Dawn,dark:Catppuccin Mocha`
#   - Herdr    via `[theme] auto_switch` (rose-pine / rose-pine-dawn)
#   - Neovim   via the OptionSet background autocmd
#
# The previous version of this script flipped Ghostty's `window-theme` key,
# which only controls window chrome — it never changed any palette.

set -euo pipefail

dark=$(osascript \
  -e 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode' \
  -e 'tell application "System Events" to tell appearance preferences to get dark mode')

if [[ "$dark" == "true" ]]; then
  mode="Dark"
else
  mode="Light"
fi

osascript -e "display notification \"Switched to $mode\" with title \"Appearance\""
