# ~/.bashrc: executed by bash(1) for non-login shells.
# Configuration lives in fragments under ~/.config/bash/.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ~/.local/bin first so scripts like regenerate-fastfetch are found.
path_add "$HOME/.local/bin" 2>/dev/null || true

# Load config fragments in numeric order
for frag in "$HOME"/.config/bash/*.sh; do
    [ -f "$frag" ] && . "$frag"
done
