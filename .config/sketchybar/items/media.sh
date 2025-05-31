#!/bin/bash

# Define the Spotify playback event once
SPOTIFY_EVENT="com.spotify.client.PlaybackStateChanged"
sketchybar --add event spotify_change "$SPOTIFY_EVENT"

# UUID of the built-in display
BUILTIN_UUID="37D8832A-2D66-02CA-B9F7-8F30A301B230"

# Retrieve the list of displays
displays_json=$(sketchybar --query displays)

# Initialize a counter for naming items
counter=1

# Iterate over each display
echo "$displays_json" | jq -c '.[]' | while read -r display; do
    # Extract the display's UUID and Arrangement ID
    uuid=$(echo "$display" | jq -r '.UUID')
    display_id=$(echo "$display" | jq -r '."arrangement-id"')

    # Determine the position based on the UUID
    if [ "$uuid" = "$BUILTIN_UUID" ]; then
        position="e"
    else
        position="center"
    fi

    echo "display_id for $display: $display_id $position"

    # Define a unique item name
    item_name="media_$counter"

    # Add and configure the item for this display
    sketchybar --add item "$item_name" "$position" \
        --set "$item_name" \
        display="$display_id" \
        label.color="$ACCENT_COLOR" \
        label.max_chars=20 \
        icon.padding_left=0 \
        scroll_texts=on \
        icon=􀑪 \
        icon.color="$ACCENT_COLOR" \
        background.drawing=off \
        script="$PLUGIN_DIR/media.sh" \
        --subscribe "$item_name" media_change spotify_change

    # Increment the counter for the next item
    counter=$((counter + 1))
done

