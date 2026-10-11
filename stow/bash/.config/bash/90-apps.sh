# ~/.config/bash/90-apps.sh — apps on shell startup

# Regenerate fastfetch config.jsonc to match the running distro + WM.
# Sourcedes presets from ~/.local/share/fastfetch/{presets,images}.
# Output is written to config.jsonc; only fastfetch's own output
# should appear in the terminal after this block.
if command -v regenerate-fastfetch >/dev/null 2>&1; then
    regenerate-fastfetch --quiet 2>/dev/null || true
fi

if command -v fastfetch >/dev/null 2>&1; then
    fastfetch --config os/debian
fi

# Initialize zoxide
eval "$(zoxide init bash)"
