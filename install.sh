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

ALL_PACKAGES=(bash fastfetch nvim starship hypr waybar wofi wlogout gtk kitty apps)
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
        apt:mako)  echo "mako-notifier" ;;
        apt:python3-gobject) echo "python3-gi" ;;
        pacman:python3-gobject) echo "python-gobject" ;;
        apk:python3-gobject) echo "py3-gobject3" ;;
        apt:libnotify) echo "libnotify-bin" ;;
        zypper:libnotify) echo "libnotify-tools" ;;
        dnf:gvfs-backends|pacman:gvfs-backends|zypper:gvfs-backends|apk:gvfs-backends|xbps:gvfs-backends)
            echo "gvfs" ;;
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

have() { command -v "$1" >/dev/null 2>&1; }

enable_debian_backports() {
    [ "$PKG_MGR" = "apt" ] || return 0
    [ -r /etc/os-release ] || return 0

    local id codename file
    id="$(. /etc/os-release; printf '%s' "${ID:-}")"
    codename="$(. /etc/os-release; printf '%s' "${VERSION_CODENAME:-}")"
    [ "$id" = "debian" ] && [ -n "$codename" ] || return 0

    file="/etc/apt/sources.list.d/debian-backports.sources"
    [ -f "$file" ] && return 0

    log "Enabling Debian ${codename}-backports..."
    printf 'Types: deb\nURIs: http://deb.debian.org/debian\nSuites: %s-backports\nComponents: main contrib non-free non-free-firmware\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\n' "$codename" \
        | $SUDO tee "$file" >/dev/null \
        || warn "Could not add Debian backports."
}

install_brave() {
    if have brave-browser || have brave; then
        log "Brave is already installed; skipping."
        return 0
    fi

    case "$PKG_MGR" in
        apt)
            install_pkgs curl ca-certificates gnupg
            log "Adding the Brave apt repository..."
            if curl -fsSLo /tmp/brave-browser-archive-keyring.gpg \
                "https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg"; then
                $SUDO install -m 0644 /tmp/brave-browser-archive-keyring.gpg \
                    /usr/share/keyrings/brave-browser-archive-keyring.gpg \
                    || warn "Could not install the Brave keyring."
                rm -f /tmp/brave-browser-archive-keyring.gpg
            else
                warn "Could not download the Brave apt keyring."
                return 0
            fi
            printf 'deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main\n' \
                | $SUDO tee /etc/apt/sources.list.d/brave-browser-release.list >/dev/null \
                || { warn "Could not add the Brave apt repository."; return 0; }
            $SUDO apt update || warn "apt update failed after adding Brave."
            install_pkgs brave-browser
            ;;
        dnf)
            install_pkgs curl ca-certificates
            log "Adding the Brave RPM repository..."
            $SUDO rpm --import "https://brave-browser-rpm-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
                || warn "Could not import the Brave RPM key."
            $SUDO curl -fsSLo /etc/yum.repos.d/brave-browser.repo \
                "https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo" \
                || { warn "Could not add the Brave RPM repository."; return 0; }
            install_pkgs brave-browser
            ;;
        zypper)
            install_pkgs curl ca-certificates
            log "Adding the Brave RPM repository..."
            $SUDO rpm --import "https://brave-browser-rpm-release.s3.brave.com/brave-browser-archive-keyring.gpg" \
                || warn "Could not import the Brave RPM key."
            $SUDO zypper --non-interactive addrepo --refresh \
                "https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo" \
                || warn "Could not add the Brave RPM repository."
            install_pkgs brave-browser
            ;;
        pacman)
            if have yay; then
                yay -S --needed --noconfirm brave-bin \
                    || warn "Could not install brave-bin from the AUR."
            elif have paru; then
                paru -S --needed --noconfirm brave-bin \
                    || warn "Could not install brave-bin from the AUR."
            else
                warn "Brave on Arch is in the AUR (brave-bin); install yay/paru or use Flatpak."
            fi
            ;;
        *)
            if have flatpak; then
                flatpak install -y flathub com.brave.Browser \
                    || warn "Could not install Brave via Flatpak."
            else
                warn "Brave has no native package for $PKG_MGR; install it manually or via Flatpak."
            fi
            ;;
    esac
}

install_nemo() {
    install_pkgs nemo nemo-fileroller gvfs gvfs-backends \
        xdg-desktop-portal xdg-desktop-portal-gtk xdg-utils
    if have nemo && have xdg-mime; then
        xdg-mime default nemo.desktop inode/directory 2>/dev/null \
            && log "Nemo set as the default file manager." \
            || warn "Could not set Nemo as the default file manager."
    fi
}

motrix_pinned_url() {
    local ver="2.0.0-beta.52"
    local base="https://github.com/agalwood/Motrix/releases/download/v${ver}"
    case "$PKG_MGR:$(uname -m)" in
        apt:x86_64) echo "$base/Motrix_${ver}_amd64.deb" ;;
        apt:aarch64|apt:arm64) echo "$base/Motrix_${ver}_arm64.deb" ;;
        dnf:x86_64|zypper:x86_64) echo "$base/Motrix-${ver}.x86_64.rpm" ;;
        dnf:aarch64|dnf:arm64|zypper:aarch64|zypper:arm64) echo "$base/Motrix-${ver}.aarch64.rpm" ;;
        pacman:x86_64) echo "$base/Motrix-${ver}-x64.pacman" ;;
        pacman:aarch64|pacman:arm64) echo "$base/Motrix-${ver}-aarch64.pacman" ;;
        *:x86_64) echo "$base/Motrix-${ver}-x86_64.AppImage" ;;
        *:aarch64|*:arm64) echo "$base/Motrix-${ver}-arm64.AppImage" ;;
    esac
}

install_motrix() {
    if have motrix; then
        log "Motrix is already installed; skipping."
        return 0
    fi

    install_pkgs curl ca-certificates
    local api="https://api.github.com/repos/agalwood/Motrix/releases?per_page=20"
    local json pattern url tmp file
    json="$(curl -fsSL "$api" 2>/dev/null || true)"
    [ -n "$json" ] || warn "Could not query the Motrix releases API; trying the pinned release."

    case "$PKG_MGR" in
        apt)
            case "$(dpkg --print-architecture 2>/dev/null || echo amd64)" in
                arm64) pattern='Motrix_.*_arm64\.deb$' ;;
                *)     pattern='Motrix_.*_amd64\.deb$' ;;
            esac
            ;;
        dnf|zypper)
            case "$(uname -m)" in
                aarch64|arm64) pattern='Motrix-.*\.aarch64\.rpm$' ;;
                *)             pattern='Motrix-.*\.x86_64\.rpm$' ;;
            esac
            ;;
        pacman)
            case "$(uname -m)" in
                aarch64|arm64) pattern='Motrix-.*-aarch64\.pacman$' ;;
                *)             pattern='Motrix-.*-x64\.pacman$' ;;
            esac
            ;;
        *)
            case "$(uname -m)" in
                x86_64) pattern='Motrix-.*-x86_64\.AppImage$' ;;
                aarch64|arm64) pattern='Motrix-.*-arm64\.AppImage$' ;;
                *) pattern='' ;;
            esac
            ;;
    esac

    url=""
    if [ -n "$pattern" ]; then
        if have jq; then
            url="$(printf '%s' "$json" \
                | jq -r '.[] | select(.prerelease) | .assets[].browser_download_url' 2>/dev/null \
                | grep -E "$pattern" | head -n1 || true)"
        else
            url="$(printf '%s' "$json" \
                | grep -o '"browser_download_url": *"[^"]*"' \
                | sed 's/.*"\(https[^"]*\)"/\1/' \
                | grep -E '/download/v2\.0\.0-beta\.' \
                | grep -E "$pattern" | head -n1 || true)"
        fi
    fi

    if [ -z "$url" ]; then
        url="$(motrix_pinned_url)"
        if [ -n "$url" ] && ! curl -fsIL "$url" >/dev/null 2>&1; then
            url=""
        fi
    fi

    if [ -z "$url" ]; then
        warn "Could not find a Motrix release asset for $PKG_MGR/$(uname -m)."
        warn "Download manually from https://github.com/agalwood/Motrix/releases"
        return 0
    fi

    tmp="$(mktemp -d)"
    file="$tmp/$(basename "${url%%\?*}")"
    log "Downloading $(basename "$file")..."
    if ! curl -fL --retry 2 -o "$file" "$url"; then
        warn "Could not download the Motrix package."
        rm -rf "$tmp"
        return 0
    fi

    case "$PKG_MGR" in
        apt)
            $SUDO apt install -y "$file" || warn "Could not install the Motrix .deb."
            ;;
        dnf)
            $SUDO dnf install -y "$file" || warn "Could not install the Motrix .rpm."
            ;;
        zypper)
            $SUDO zypper --non-interactive install --allow-unsigned-rpm "$file" \
                || warn "Could not install the Motrix .rpm."
            ;;
        pacman)
            $SUDO pacman -U --noconfirm "$file" || warn "Could not install the Motrix package."
            ;;
        *)
            if [ "${file##*.}" = "AppImage" ]; then
                mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
                cp "$file" "$HOME/.local/bin/motrix"
                chmod +x "$HOME/.local/bin/motrix"
                cat > "$HOME/.local/share/applications/motrix.desktop" <<EOF
[Desktop Entry]
Name=Motrix
Exec=$HOME/.local/bin/motrix
Icon=motrix
Terminal=false
Type=Application
Categories=Network;FileTransfer;
EOF
                log "Motrix AppImage installed to ~/.local/bin/motrix."
            else
                warn "Unsupported Motrix package for $PKG_MGR."
            fi
            ;;
    esac
    rm -rf "$tmp"
}

install_opencode() {
    if have opencode || [ -x "$HOME/.opencode/bin/opencode" ]; then
        log "opencode is already installed; skipping."
        return 0
    fi

    install_pkgs curl ca-certificates tar
    log "Installing opencode..."
    if curl -fsSL "https://opencode.ai/install" | bash -s -- --no-modify-path; then
        log "opencode installed to ~/.opencode/bin."
    elif have npm; then
        warn "Official opencode installer failed; trying npm..."
        npm i -g opencode-ai || warn "Could not install opencode."
    else
        warn "Could not install opencode."
    fi
}

install_hyprshot() {
    if have hyprshot || [ -x "$HOME/.local/bin/hyprshot" ]; then
        return 0
    fi

    install_pkgs curl grim slurp wl-clipboard jq libnotify
    mkdir -p "$HOME/.local/bin"
    if curl -fsSL "https://raw.githubusercontent.com/Gustash/Hyprshot/master/hyprshot" \
        -o "$HOME/.local/bin/hyprshot"; then
        chmod +x "$HOME/.local/bin/hyprshot"
        log "hyprshot installed to ~/.local/bin."
    else
        warn "Could not install hyprshot."
    fi
}

# ---------------------------------------------------------------------------
# 4. Interactive selection (skipped with -y / -a / -p)
# ---------------------------------------------------------------------------
if [ ${#SELECTED_PACKAGES[@]} -eq 0 ]; then
    if command -v whiptail >/dev/null 2>&1; then
        CHOICES=$(whiptail --title "Potaterrr Dotfiles Installer" \
            --checklist "Use [Space] to select/deselect packages to install & stow:" 22 78 12 \
            "bash" "Bash shell configurations & aliases" ON \
            "nvim" "Neovim (LazyVim setup)" ON \
            "starship" "Starship prompt preset" ON \
            "fastfetch" "Fastfetch system info tool" ON \
            "hypr" "Hyprland window manager setup" OFF \
            "waybar" "Waybar status bar" OFF \
            "wofi" "Wofi application launcher" OFF \
            "wlogout" "Wlogout power menu (lock / logout / reboot)" OFF \
            "gtk" "GTK cursor theme (Bibata Modern Ice)" OFF \
            "kitty" "Kitty terminal configuration" OFF \
            "apps" "Brave, Nemo, Motrix, opencode, kitty, yazi" OFF \
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

    enable_debian_backports

    log "Refreshing package lists..."
    eval "$PKG_UPDATE"

    log "Installing core dependencies (git, stow, curl)..."
    install_pkgs git stow curl ca-certificates

    for pkg in "${SELECTED_PACKAGES[@]}"; do
        case "$pkg" in
#aria2 now installed with bash package (ripgrep too)
            bash)      install_pkgs aria2 ripgrep ;;
            nvim)      install_pkgs nvim ripgrep make unzip git ;;
            starship)  install_pkgs starship ;;
            fastfetch) install_pkgs fastfetch ;;
            hypr)      install_pkgs hyprland hyprpaper hyprlock hypridle wlogout \
                              kitty yazi btop brightnessctl pipewire wireplumber mako qt6ct \
                              python3 python3-gobject python3-cairo \
                              xdg-desktop-portal xdg-desktop-portal-gtk xdg-desktop-portal-hyprland
                       install_hyprshot ;;
            waybar)    install_pkgs waybar mako wofi jq libnotify ;;
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
            kitty)     install_pkgs kitty ;;
            apps)      install_pkgs kitty yazi jq xdg-utils
                       install_nemo
                       install_brave
                       install_motrix
                       install_opencode ;;
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
    [ "$pkg" = "apps" ] && continue
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
#    Installs the systemd user unit so the 󰅶/󰾪 waybar module works out of
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
        echo "    Caffeine mode: toggle with Super+C or click the 󰾪/󰅶 icon on waybar."
    fi
done

log "Dotfiles setup complete!"
echo "    Next: start a new shell (or run 'source ~/.bashrc') to load the bash config."
echo "    Package commands (update/install/remove/search) now work on this distro."
