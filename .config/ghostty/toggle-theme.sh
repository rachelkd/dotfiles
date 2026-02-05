#!/usr/bin/env bash
# Toggle between light and dark window themes

# Resolve symlink to get the actual config file
config_symlink="$HOME/.config/ghostty/config"
config_file=$(readlink -f "$config_symlink" 2>/dev/null || realpath "$config_symlink" 2>/dev/null || echo "$config_symlink")

current_theme=$(grep "^window-theme" "$config_file" | awk '{print $3}' | tr -d '"')

if [[ "$current_theme" == "light" ]]; then
  new_theme="dark"
elif [[ "$current_theme" == "dark" ]]; then
  new_theme="light"
else
  # If "auto" or anything else, default to light
  new_theme="light"
fi

sed -i '' "s/^window-theme = \".*\"/window-theme = \"$new_theme\"/" "$config_file"
