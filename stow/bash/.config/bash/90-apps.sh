# ~/.config/bash/90-apps.sh — apps on shell startup

# Keep fastfetch config in sync with the running distro + WM.
# souravas presets live in ~/.local/share/fastfetch/{presets,images};
# this regenerator picks the right logo + module layout at shell start.
if command -v fastfetch >/dev/null 2>&1 && command -v regenerate-fastfetch >/dev/null 2>&1; then
    regenerate-fastfetch --quiet 2>/dev/null || true
    if [ -f "$HOME/.config/fastfetch/groups/debian" ]; then
        fastfetch --config groups/debian
    else
        fastfetch # uses ~/.config/fastfetch/config.jsonc
    fi
fi

# Initialize zoxide
eval "$(zoxide init bash)"
