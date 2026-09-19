# ~/.config/bash/15-package-manager.sh — distro-agnostic package helpers
# Detects the system package manager and exposes the same commands everywhere:
#   pkg_update / pkg_upgrade / pkg_install <pkgs...> / pkg_remove <pkgs...> / pkg_search <term>
# $PKG_MGR holds the detected manager name (apt, dnf, pacman, zypper, apk, xbps).

if command -v apt >/dev/null 2>&1; then
    PKG_MGR=apt
    pkg_update()  { sudo apt update; }
    pkg_upgrade() { sudo apt upgrade -y; }
    pkg_install() { sudo apt install -y "$@"; }
    pkg_remove()  { sudo apt purge -y "$@" && sudo apt autoremove -y; }
    pkg_search()  { apt search "$@"; }

elif command -v dnf >/dev/null 2>&1; then
    PKG_MGR=dnf
    pkg_update()  { sudo dnf check-update || true; } # exit 100 just means updates available
    pkg_upgrade() { sudo dnf upgrade -y; }
    pkg_install() { sudo dnf install -y "$@"; }
    pkg_remove()  { sudo dnf remove -y "$@"; }
    pkg_search()  { dnf search "$@"; }

elif command -v pacman >/dev/null 2>&1; then
    PKG_MGR=pacman
    pkg_update()  { sudo pacman -Sy; }
    pkg_upgrade() { sudo pacman -Syu --noconfirm; }
    pkg_install() { sudo pacman -S --needed --noconfirm "$@"; }
    pkg_remove()  { sudo pacman -Rns --noconfirm "$@"; }
    pkg_search()  { pacman -Ss "$@"; }

elif command -v zypper >/dev/null 2>&1; then
    PKG_MGR=zypper
    pkg_update()  { sudo zypper refresh; }
    pkg_upgrade() { sudo zypper --non-interactive dup; }
    pkg_install() { sudo zypper --non-interactive install "$@"; }
    pkg_remove()  { sudo zypper --non-interactive remove "$@"; }
    pkg_search()  { zypper search "$@"; }

elif command -v apk >/dev/null 2>&1; then
    PKG_MGR=apk
    pkg_update()  { sudo apk update; }
    pkg_upgrade() { sudo apk upgrade; }
    pkg_install() { sudo apk add "$@"; }
    pkg_remove()  { sudo apk del "$@"; }
    pkg_search()  { apk search -v "$@"; }

elif command -v xbps-install >/dev/null 2>&1; then
    PKG_MGR=xbps
    pkg_update()  { sudo xbps-install -S; }
    pkg_upgrade() { sudo xbps-install -Su; }
    pkg_install() { sudo xbps-install -S "$@"; }
    pkg_remove()  { sudo xbps-remove -R "$@"; }
    pkg_search()  { xbps-query -Rs "$@"; }

else
    PKG_MGR=unknown
    pkg_install() { echo "pkg: no supported package manager found; install manually: $*" >&2; return 1; }
    pkg_remove()  { pkg_install "$@"; }
    pkg_update()  { echo "pkg: no supported package manager found" >&2; return 1; }
    pkg_upgrade() { pkg_update "$@"; }
    pkg_search()  { echo "pkg: no supported package manager found" >&2; return 1; }
fi
