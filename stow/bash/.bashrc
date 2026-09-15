# ~/.bashrc: executed by bash(1) for non-login shells.
# Configuration lives in fragments under ~/.config/bash/.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# Load config fragments in numeric order
for frag in "$HOME"/.config/bash/*.sh; do
    [ -f "$frag" ] && . "$frag"
done
