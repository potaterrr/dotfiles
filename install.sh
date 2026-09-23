#!/usr/bin/env bash
# Potaterrr dotfiles installer — works on Debian/Ubuntu, Fedora, Arch,
# openSUSE, Alpine, and Void. Interactive or fully non-interactive.

set -euo pipefail

REPO_URL="https://github.com/potaterrr/dotfiles.git"
DOTFILES_BASE="${DOTFILES_BASE:-$HOME/git-projects/dotfiles}"
STOW_TARGET="${STOW_TARGET:-$HOME}"
# Canonicalize to physical paths so symlinked targets can't alias repo files.
# (Best-effort: paths may not exist yet before the clone step.)
DOTFILES_BASE="$(cd "$DOTFILES_BASE" 2>/dev/null && pwd -P || printf %s "$DOTFILES_BASE")"
TARGET_DIR="$(cd "$STOW_TARGET" 2>/dev/null && pwd -P || printf %s "$STOW_TARGET")"
DOTFILES_DIR="$DOTFILES_BASE/stow"

ALL_PACKAGES=(bash fastfetch nvim starship hypr waybar wofi wlogout gtk)
# Default for non-interactive runs (override with: PACKAGES="bash nvim" ./install.sh -y)
DEFAULT_PACKAGES=(bash nvim starship fastfetch)

log()  { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*"; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<EOF
Usage: ./install.sh [options]

Options:
  -y, --yes            Non-interactive: install the default set (or \$PACKAGES)
  -a, --all            Non-interactive: install every package
  -p, --packages LIST  Quoted, space-separated list, e.g. -p "bash nvim waybar"
      --no-pull        Skip 'git pull' when the repo already exists locally
  -h, --help           Show this help

Environment:
  PACKAGES="bash nvim"  Package selection for -y mode
  DOTFILES_BASE=...     Where to clone the repo (default ~/git-projects/dotfiles)
  STOW_TARGET=...       Stow target dir (default \$HOME)
EOF
}

# ---------------------------------------------------------------------------
# 0. Parse arguments
# ---------------------------------------------------------------------------
ASSUME_YES=0
INSTALL_ALL=0
DO_PULL=1
PACKAGE_ARG=""

while [ $# -gt 0 ]; do
    case "$1" in
        -y|--yes)      ASSUME_YES=1 ;;
        -a|--all)      ASSUME_YES=1; INSTALL_ALL=1 ;;
        -p|--packages) PACKAGE_ARG="${2:-}"; shift ;;
        --no-pull)     DO_PULL=0 ;;
        -h|--help)     usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift
done

SELECTED_PACKAGES=()
if [ "$INSTALL_ALL" -eq 1 ]; then
    SELECTED_PACKAGES=("${ALL_PACKAGES[@]}")
elif [ -n "$PACKAGE_ARG" ]; then
    # shellcheck disable=SC2206
    SELECTED_PACKAGES=($PACKAGE_ARG)
elif [ "$ASSUME_YES" -eq 1 ] && [ -n "${PACKAGES:-}" ]; then
    # shellcheck disable=SC2206
    SELECTED_PACKAGES=($PACKAGES)
elif [ "$ASSUME_YES" -eq 1 ]; then
    SELECTED_PACKAGES=("${DEFAULT_PACKAGES[@]}")
fi

# ---------------------------------------------------------------------------
# 1. Preflight: git
# ---------------------------------------------------------------------------
command -v git >/dev/null 2>&1 || die "git is required to download dotfiles. Install git first."

# ---------------------------------------------------------------------------
# 2. Clone or update the repository
# ---------------------------------------------------------------------------
if [ ! -d "$DOTFILES_BASE/.git" ]; then
    log "Cloning dotfiles repository into $DOTFILES_BASE..."
    mkdir -p "$(dirname "$DOTFILES_BASE")"
    git clone "$REPO_URL" "$DOTFILES_BASE"
elif [ "$DO_PULL" -eq 1 ]; then
    log "Updating existing repository..."
    git -C "$DOTFILES_BASE" pull --ff-only origin main || warn "git pull failed; continuing with local copy"
fi

cd "$DOTFILES_BASE"

# ---------------------------------------------------------------------------
# 3. Privilege + package manager detection
#    apt | dnf | pacman | zypper | apk | xbps
# ---------------------------------------------------------------------------
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1; then
        SUDO="sudo"
    else
        die "Not running as root and sudo is not installed. Install sudo or run as root."
    fi
fi

PKG_MGR="unknown"
command -v apt          >/dev/null 2>&1 && PKG_MGR="apt"
command -v dnf          >/dev/null 2>&1 && PKG_MGR="dnf"
command -v pacman       >/dev/null 2>&1 && PKG_MGR="pacman"
command -v zypper       >/dev/null 2>&1 && PKG_MGR="zypper"
command -v apk          >/dev/null 2>&1 && PKG_MGR="apk"
command -v xbps-install >/dev/null 2>&1 && PKG_MGR="xbps"

# Testing/edge override: PKG_MGR_FORCE=pacman ./install.sh -y
[ -n "${PKG_MGR_FORCE:-}" ] && PKG_MGR="$PKG_MGR_FORCE"

case "$PKG_MGR" in
    apt)    PKG_UPDATE="$SUDO apt update";                        PKG_INSTALL="$SUDO apt install -y" ;;
    dnf)    PKG_UPDATE="$SUDO dnf makecache --quiet || true";     PKG_INSTALL="$SUDO dnf install -y" ;;
    pacman) PKG_UPDATE="$SUDO pacman -Sy";                        PKG_INSTALL="$SUDO pacman -S --needed --noconfirm" ;;
    zypper) PKG_UPDATE="$SUDO zypper refresh";                    PKG_INSTALL="$SUDO zypper --non-interactive install" ;;
    apk)    PKG_UPDATE="$SUDO apk update";                        PKG_INSTALL="$SUDO apk add" ;;
    xbps)   PKG_UPDATE="$SUDO xbps-install -S";                   PKG_INSTALL="$SUDO xbps-install -y" ;;
    *)      PKG_UPDATE="";                                        PKG_INSTALL="" ;;
esac

# Map logical package names to distro-specific ones (add more as needed)
pkg_name() {
    case "$PKG_MGR:$1" in
        *:hypr)    echo "hyprland" ;;
        apt:brave) echo "brave-browser" ;;
        *)         echo "$1" ;;
    esac
}

# install_pkgs <pkg>... — batch install first; on failure retry one-by-one and
# only warn about packages that this distro's repos don't carry.
install_pkgs() {
    if [ -z "$PKG_INSTALL" ]; then
        warn "No package manager detected; install manually: $*"
        return 0
    fi

    local -a names=()
    local rp name
    for rp in "$@"; do
        names+=("$(pkg_name "$rp")")
    done

    if eval "$PKG_INSTALL ${names[*]}"; then
        return 0
    fi

    warn "Batch install failed; retrying package-by-package..."
    local missing=""
    for name in "${names[@]}"; do
        eval "$PKG_INSTALL $name" || missing="$missing $name"
    done
    if [ -n "$missing" ]; then
        warn "Not available in $PKG_MGR repos:$missing (install manually if needed)"
    fi
    return 0
}

# ---------------------------------------------------------------------------
# 4. Interactive selection (skipped with -y / -a / -p)
# ---------------------------------------------------------------------------
if [ ${#SELECTED_PACKAGES[@]} -eq 0 ]; then
    if command -v whiptail >/dev/null 2>&1; then
        CHOICES=$(whiptail --title "Potaterrr Dotfiles Installer" \
            --checklist "Use [Space] to select/deselect packages to install & stow:" 20 78 10 \
            "bash" "Bash shell configurations & aliases" ON \
            "nvim" "Neovim (LazyVim setup)" ON \
            "starship" "Starship prompt preset" ON \
            "fastfetch" "Fastfetch system info tool" ON \
            "hypr" "Hyprland window manager setup" OFF \
            "waybar" "Waybar status bar" OFF \
            "wofi" "Wofi application launcher" OFF \
            "wlogout" "Wlogout power menu (lock / logout / reboot)" OFF \
            "gtk" "GTK cursor theme (Bibata Modern Ice)" OFF \
            3>&1 1>&2 2>&3) || { echo "Installation cancelled by user."; exit 0; }
        # shellcheck disable=SC2206
        SELECTED_PACKAGES=($(echo "$CHOICES" | tr -d '"'))
    elif [ -t 0 ] && [ -t 1 ]; then
        # Portable numbered menu for distros without whiptail
        echo "==> Select packages (space-separated numbers, 'a' = all, ENTER = confirm):"
        i=1
        for p in "${ALL_PACKAGES[@]}"; do
            def=" "
            case "$p" in bash|nvim|starship|fastfetch) def="x" ;; esac
            printf '  [%s] %d) %s\n' "$def" "$i" "$p"
            i=$((i + 1))
        done
        chosen=""
        while true; do
            printf 'Your choice (e.g. "1 2 4", "a"): '
            IFS= read -r answer
            answer=$(printf %s "$answer" | tr -d "\"'")
            case "$answer" in
                a|A) chosen="${ALL_PACKAGES[*]}"; break ;;
                "")  [ -n "$chosen" ] && break; echo "Nothing selected yet." ;;
                *)   chosen=""
                     ok=1
                     for n in $answer; do
                         if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt ${#ALL_PACKAGES[@]} ]; then
                             echo "Invalid choice: $n"
                             ok=0
                             break
                         fi
                         chosen="$chosen ${ALL_PACKAGES[$((n - 1))]}"
                     done
                     [ "$ok" -eq 1 ] && [ -n "$chosen" ] && break ;;
            esac
        done
        # shellcheck disable=SC2086
        SELECTED_PACKAGES=($chosen)
    else
        # No whiptail, no TTY (e.g. curl | bash): fall back to the core set
        warn "No interactive terminal detected; using default package set."
        SELECTED_PACKAGES=("${DEFAULT_PACKAGES[@]}")
    fi
fi

echo "==> Selected packages: ${SELECTED_PACKAGES[*]}"

# ---------------------------------------------------------------------------
# 5. Dependencies
# ---------------------------------------------------------------------------
if [ -n "$PKG_INSTALL" ]; then
    log "Detected package manager: $PKG_MGR"

    log "Refreshing package lists..."
    eval "$PKG_UPDATE"

    log "Installing core dependencies (git, stow)..."
    install_pkgs git stow

    for pkg in "${SELECTED_PACKAGES[@]}"; do
        case "$pkg" in
            bash)      install_pkgs aria2 ;;                                  # download() helper
            nvim)      install_pkgs nvim ripgrep make unzip git ;;
            starship)  install_pkgs starship ;;
            fastfetch) install_pkgs fastfetch ;;
            hypr)      install_pkgs hyprland hyprpaper hyprlock hypridle hyprshot wlogout \
                              kitty yazi btop brave brightnessctl pipewire wireplumber dunst qt6ct \
                              python3 python3-gobject python3-cairo ;;
            waybar)    install_pkgs waybar dunst ;;
            wofi)      install_pkgs wofi ;;
            wlogout)   install_pkgs wlogout ;;
            gtk)       install_pkgs bibata-cursor-theme
                       # Fallback: fetch Bibata Modern Ice from GitHub releases
                       # when this distro doesn't package it (user-level install)
                       if [ ! -d "$HOME/.local/share/icons/Bibata-Modern-Ice" ] \
                          && [ ! -d "/usr/share/icons/Bibata-Modern-Ice" ]; then
                           log "Fetching Bibata Modern Ice from GitHub releases..."
                           mkdir -p "$HOME/.local/share/icons" /tmp/bibata-dl
                           curl -fsSL -o /tmp/bibata-dl/bibata.tar.xz \
                               "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz" \
                               && tar -xf /tmp/bibata-dl/bibata.tar.xz -C /tmp/bibata-dl \
                               && cp -r /tmp/bibata-dl/Bibata-Modern-Ice "$HOME/.local/share/icons/" \
                               || warn "Could not download Bibata cursor; install it manually"
                           rm -rf /tmp/bibata-dl
                       fi ;;
        esac
    done
else
    warn "Unsupported distribution (no apt/dnf/pacman/zypper/apk/xbps found)."
    warn "Install 'stow' and your packages' tools manually, then re-run this script to stow."
fi

# ---------------------------------------------------------------------------
# 6. GNU Stow — conflict-safe
# ---------------------------------------------------------------------------
command -v stow >/dev/null 2>&1 || die "GNU stow is not installed and could not be installed automatically."

# Back up real files in $TARGET_DIR that would collide with stow's symlinks
# (e.g. /etc/skel's .bashrc on a fresh distro install).
# Safety: never touch anything that resolves inside the dotfiles repo itself
# (possible when the target contains symlinks pointing back into the repo).
backup_conflicts() {
    local pkg="$1" rel target dir resolved_dir ts
    while IFS= read -r rel; do
        target="$TARGET_DIR/${rel#./}"
        case "$target" in
            *.pre-stow.*) continue ;;   # never re-back-up our own backups
        esac
        [ -f "$target" ] && [ ! -L "$target" ] || continue

        dir="${target%/*}"
        resolved_dir="$(cd "$dir" 2>/dev/null && pwd -P)" || continue
        case "$resolved_dir" in
            "$DOTFILES_BASE"|"$DOTFILES_BASE"/*) continue ;;  # inside the repo: hands off
        esac

        ts=$(date +%Y%m%d-%H%M%S)
        warn "$pkg: existing file $target -> backing up to ${target}.pre-stow.$ts"
        mv "$target" "${target}.pre-stow.$ts"
    done < <(cd "$DOTFILES_DIR/$pkg" && find . -type f | sort)
}

log "Applying configurations via GNU Stow (target: $TARGET_DIR)..."
for pkg in "${SELECTED_PACKAGES[@]}"; do
    if [ -d "$DOTFILES_DIR/$pkg" ]; then
        backup_conflicts "$pkg"
        log "Stowing $pkg..."
        stow -d "$DOTFILES_DIR" -t "$TARGET_DIR" -R "$pkg" || warn "stow had issues with $pkg (see output above)"
    else
        warn "Package '$pkg' not found in stow/, skipping."
    fi
done

# ---------------------------------------------------------------------------
# 7. Waybar extras — caffeine mode (idle inhibitor for hypridle)
#    Installs the systemd user unit so the ☕/💤 waybar module works out of
#    the box; toggle with Super+C, the bar icon, or `make -C ~/.config/waybar`.
# ---------------------------------------------------------------------------
for p in "${SELECTED_PACKAGES[@]}"; do
    if [ "$p" = "waybar" ] && [ -f "$DOTFILES_DIR/systemd/.config/systemd/user/caffeine.service" ]; then
        CAFFEINE_UNIT_DST="$TARGET_DIR/.config/systemd/user/caffeine.service"
        log "Installing caffeine mode (idle inhibitor)..."
        mkdir -p "$(dirname "$CAFFEINE_UNIT_DST")"
        cp "$DOTFILES_DIR/systemd/.config/systemd/user/caffeine.service" "$CAFFEINE_UNIT_DST"
        [ -f "$TARGET_DIR/.config/waybar/scripts/caffeine.sh" ] \
            && chmod +x "$TARGET_DIR/.config/waybar/scripts/caffeine.sh"
        systemctl --user daemon-reload 2>/dev/null \
            || warn "Could not reload systemd user units; run 'systemctl --user daemon-reload' later."
        echo "    Caffeine mode: toggle with Super+C or click the 💤/☕ icon on waybar."
    fi
done

log "Dotfiles setup complete!"
echo "    Next: start a new shell (or run 'source ~/.bashrc') to load the bash config."
echo "    Package commands (update/install/remove/search) now work on this distro."
