#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "=== Starting Universal Dotfiles Deployment ==="

# Define Dotfiles Directory (where this script lives)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 0. Check for uncommitted changes in the dotfiles repository
if [ -d "$DOTFILES_DIR/.git" ]; then
    echo "Checking Git status..."
    if [ -n "$(git -C "$DOTFILES_DIR" status --porcelain)" ]; then
        echo -e "\n⚠️  WARNING: You have uncommitted changes in your dotfiles repository!"
        git -C "$DOTFILES_DIR" status -s
        echo ""
        read -p "Do you still want to proceed with the installation? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Installation aborted. Please commit or stash your changes first."
            exit 1
        fi
    else
        echo "✅ Git repository is clean. Proceeding..."
    fi
fi

# 1. Detect Package Manager and Install Dependencies
if command -v apt &> /dev/null; then
    echo "Detected Debian/Ubuntu-based system..."
    sudo apt update
    sudo apt install -y hyprland waybar swaync wireplumber tlp git curl
elif command -v pacman &> /dev/null; then
    echo "Detected Arch-based system..."
    sudo pacman -Syu --needed hyprland waybar swaync wireplumber tlp git curl
elif command -v dnf &> /dev/null; then
    echo "Detected Fedora-based system..."
    sudo dnf install -y hyprland waybar swaync wireplumber tlp git curl
elif command -v zypper &> /dev/null; then
    echo "Detected openSUSE-based system..."
    sudo zypper install -y hyprland waybar swaync wireplumber tlp git curl
else
    echo "⚠️ Warning: Unknown package manager. Skipping automated package installation."
    echo "Please ensure you manually install: hyprland, waybar, swaync, wireplumber, and tlp."
fi

# 2. Setup Configuration Symlinks with Safety Backup
BACKUP_DIR="$HOME/.config/dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
BACKUP_CREATED=false

echo "Setting up configurations in ~/.config..."
mkdir -p ~/.config

# List of your config directories to link
configs=("hyprland" "waybar" "swaync" "wireplumber")

for config in "${configs[@]}"; do
    TARGET="$HOME/.config/$config"
    SOURCE="$DOTFILES_DIR/$config"

    if [ -d "$SOURCE" ]; then
        # If target exists and is a real directory (not already a symlink)
        if [ -d "$TARGET" ] && [ ! -L "$TARGET" ]; then
            if [ "$BACKUP_CREATED" = false ]; then
                mkdir -p "$BACKUP_DIR"
                echo "📦 Existing local configs detected. Moving them to: $BACKUP_DIR"
                BACKUP_CREATED=true
            fi
            mv "$TARGET" "$BACKUP_DIR/"
            echo "-> Backed up existing local '$config' folder."
        elif [ -L "$TARGET" ]; then
            # If it's already a symlink from a previous install, remove the old link safely
            rm "$TARGET"
        fi

        # Create the symlink pointing to your git repository
        ln -s "$SOURCE" "$TARGET"
        echo "-> Linked '$config' successfully."
    fi
done

# 3. Enable TLP Power Management Service (if systemd is present)
if command -v systemctl &> /dev/null; then
    echo "Enabling TLP power service..."
    sudo systemctl enable --now tlp
fi

echo "=== Dotfiles installation, backup, and sync complete! ==="
