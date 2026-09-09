#!/usr/bin/env bash

# 1. Correct base directory with the 's'
WALLPAPER_DIR="$HOME/git-clones/Wallpapers"

# 2. Get active monitor name (falls back to eDP-1 if jq fails)
MONITOR=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name' 2>/dev/null)
if [ -z "$MONITOR" ] || [ "$MONITOR" = "null" ]; then
    MONITOR="eDP-1"
fi

# 3. Recursively find a random image from any subfolder (handles spaces safely)
NEW_WALL=$(find "$WALLPAPER_DIR" -type f \( -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" -o -name "*.webp" \) -print0 2>/dev/null | shuf -z -n 1 | tr -d '\0')

# 4. Apply the wallpaper via IPC if an image was found
if [ -n "$NEW_WALL" ]; then
    hyprctl hyprpaper preload "$NEW_WALL"
    hyprctl hyprpaper wallpaper "$MONITOR,$NEW_WALL"
    
    # Crucial for battery: Unload previous wallpapers from RAM/GPU cache
    hyprctl hyprpaper unload all
fi
