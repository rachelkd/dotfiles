#!/bin/bash

# Get Spotify state and track info
STATE=$(osascript -e 'tell application "Spotify" to get player state' 2>/dev/null)
if [ "$STATE" = "playing" ]; then
  TRACK=$(osascript -e 'tell application "Spotify" to get name of current track' 2>/dev/null)
  ARTIST=$(osascript -e 'tell application "Spotify" to get artist of current track' 2>/dev/null)
  LABEL="$TRACK - $ARTIST"
  sketchybar --set $NAME label="$LABEL" drawing=on
else
  sketchybar --set $NAME drawing=off
fi
