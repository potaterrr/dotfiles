# ~/.config/bash/30-aliases.sh — aliases

# Distro-agnostic package commands (defined in 15-package-manager.sh)
alias update='pkg_update && pkg_upgrade'
alias install='pkg_install'
alias remove='pkg_remove'
alias search='pkg_search'

# general shortcuts
alias c='clear'
alias ..='cd ..'
alias reload='source ~/.bashrc'
alias basher='${EDITOR:-nano} ~/.config/bash/'

# opencode
alias code='opencode'

# ls colors
if command -v dircolors >/dev/null 2>&1; then
  [ -r ~/.dircolors ] && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
  alias ls='ls --color=auto'
fi

# code editor
alias edit='nvim'

#hyprpaper (Hyprland only)
wall() {
  command -v hyprpaper >/dev/null 2>&1 || { echo "wall: hyprpaper not installed" >&2; return 1; }
  [ -z "$1" ] && { echo "Usage: wall <image>" >&2; return 1; }
  local img
  img="$(realpath "$1")" || return 1

  local conf="$HOME/.config/hypr/hyprpaper.conf"

  # Write the hyprpaper config file
  cat <<EOF >"$conf"
preload = $img
wallpaper = ,$img
EOF

  # Kill old instances quietly, then launch fresh and disown it from the shell
  killall hyprpaper 2>/dev/null
  nohup hyprpaper >/dev/null 2>&1 &
  disown
}

# Simple aria2 downloader shortcut
download() {
  if ! command -v aria2c >/dev/null 2>&1; then
    echo "download: aria2 is not installed. Install it with: pkg_install aria2" >&2
    return 1
  fi
  if [ -z "$1" ]; then
    echo "Error: Please provide a URL."
    echo "Usage: download https://example.com"
    return 1
  fi
  # Runs aria2 with 16 connections right in your current directory
  aria2c -x 16 -s 16 "$1"
}
