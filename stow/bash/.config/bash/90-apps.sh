# ~/.config/bash/90-apps.sh — apps on shell startup

if command -v fastfetch >/dev/null 2>&1; then
    if [ -f "$HOME/.config/fastfetch/groups/debian" ]; then
        fastfetch --config groups/debian
    else
        fastfetch  # uses ~/.config/fastfetch/config.jsonc
    fi
fi
