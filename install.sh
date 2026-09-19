#!/usr/bin/env bash
set -e

REPO_URL="https://github.com/potaterrr/dotfiles.git"
DOTFILES_BASE="$HOME/git-projects/dotfiles"
DOTFILES_DIR="$DOTFILES_BASE/stow"
TARGET_DIR="$HOME"

echo "==> Setting up dotfiles environment..."

# 1. Ensure git is installed first (needed for cloning)
if ! command -v git &>/dev/null; then
    echo "Git is required to download dotfiles. Please install git first."
    exit 1
fi

# 2. Clone or update the repository locally if not run from local repo
if [ ! -d "$DOTFILES_BASE/.git" ]; then
    echo "==> Cloning dotfiles repository into $DOTFILES_BASE..."
    mkdir -p "$(dirname "$DOTFILES_BASE")"
    git clone "$REPO_URL" "$DOTFILES_BASE"
else
    echo "==> Dotfiles repository already exists locally. Pulling latest changes..."
    git -C "$DOTFILES_BASE" pull origin main || true
fi

# 3. Change into the repository directory so relative paths work
cd "$DOTFILES_BASE"

echo "==> Detecting package manager..."

# 4. Detect Package Manager
if command -v apt &>/dev/null; then
    PKG_UPDATE="sudo apt update"
    PKG_INSTALL="sudo apt install -y"
elif command -v pacman &>/dev/null; then
    PKG_UPDATE="sudo pacman -Sy"
    PKG_INSTALL="sudo pacman -S --needed --noconfirm"
elif command -v dnf &>/dev/null; then
    PKG_UPDATE="sudo dnf check-update || true"
    PKG_INSTALL="sudo dnf install -y"
else
    echo "Unsupported distribution. Dependencies must be installed manually."
    PKG_INSTALL=""
fi

# 5. Interactive Selection Menu using Whiptail
if command -v whiptail &>/dev/null; then
    CHOICES=$(whiptail --title "Potaterrr Dotfiles Installer" \
        --checklist "Use [Space] to select/deselect packages to install & stow:" 20 78 8 \
        "bash" "Bash shell configurations & aliases" ON \
        "nvim" "Neovim (LazyVim setup)" ON \
        "starship" "Starship prompt preset" ON \
        "fastfetch" "Fastfetch system info tool" OFF \
        "hypr" "Hyprland window manager setup" OFF \
        "waybar" "Waybar status bar" OFF \
        "wofi" "Wofi application launcher" OFF \
        3>&1 1>&2 2>&3)

    if [ $? -ne 0 ]; then
        echo "Installation cancelled by user."
        exit 0
    fi
else
    echo "Whiptail not found. Installing all packages by default..."
    CHOICES='"bash" "nvim" "starship" "fastfetch" "hypr" "waybar" "wofi"'
fi

# Clean up quotes from whiptail output
SELECTED_PACKAGES=$(echo "$CHOICES" | tr -d '"')

# 6. Handle Dependency Installation
if [ -n "$PKG_INSTALL" ]; then
    echo "==> Updating package lists..."
    eval "$PKG_UPDATE"

    echo "==> Installing dependencies for selected components..."
    eval "$PKG_INSTALL stow git"

    for pkg in $SELECTED_PACKAGES; do
        case "$pkg" in
        nvim)
            eval "$PKG_INSTALL neovim ripgrep make unzip"
            ;;
        waybar)
            eval "$PKG_INSTALL waybar"
            ;;
        hypr)
            eval "$PKG_INSTALL hyprland hyprpaper"
            ;;
        wofi)
            eval "$PKG_INSTALL wofi"
            ;;
        starship)
            eval "$PKG_INSTALL starship"
            ;;
        fastfetch)
            eval "$PKG_INSTALL fastfetch"
            ;;
        esac
    done
fi

# 7. Run GNU Stow for Selected Packages
echo "==> Applying configurations via GNU Stow..."
cd "$DOTFILES_BASE"

for pkg in $SELECTED_PACKAGES; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        echo "Stowing $pkg..."
        stow -d "$DOTFILES_DIR" -t "$TARGET_DIR" -R "$pkg"
    else
        echo "Warning: $pkg folder not found in stow/, skipping."
    fi
done

echo "==> Dotfiles setup successfully completed!"
