<div align="center">

# 🥔 Potaterrr's Dotfiles

**A modular, cross-distribution dotfiles configuration managed with GNU Stow & an interactive installer.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Linux](https://img.shields.io/badge/Platform-Linux-blue.svg)](https://www.linux.org)
[![GNU Stow](https://img.shields.io/badge/Manager-GNU%20Stow-orange.svg)](https://www.gnu.org/software/stow/)

</div>

---

## 📸 Overview

A clean, lightweight, and reproducible dotfiles setup designed for seamless deployment across multiple Linux distributions (Debian/Ubuntu, Arch Linux, and Fedora) on both desktop workstations and servers.

---

## 📦 Included Configurations

Configurations are isolated into individual modular packages under the `stow/` directory to prevent system clutter and allow selective deployment:

| Package | Description |
| :--- | :--- |
| **`bash`** | Custom Bash shell configurations, prompts, and git aliases |
| **`nvim`** | Neovim setup powered by LazyVim |
| **`starship`** | Minimalist cross-shell prompt preset |
| **`fastfetch`** | Catppuccin-themed system info (boxed layout, potato logo, kitty graphics + ASCII fallback) |
| **`hypr`** | Hyprland dynamic tiling window manager setup (incl. hypridle, hyprlock, cursor env) |
| **`waybar`** | Custom Waybar status bar layout with caffeine mode (💤/☕ idle inhibitor) |
| **`systemd`** | `caffeine.service` user unit — auto-installed with the `waybar` package |
| **`wofi`** | Wofi application launcher configuration |
| **`gtk`** | Bibata Modern Ice cursor theme for GTK3/GTK4 apps |

---

## 🚀 Installation Guide

### Quick One-Liner Install

Bootstraps everything (clone + deps + stow) on any supported distro:

```bash
curl -fsSL https://potaterrr.github.io/install | sh
```

Prefer to review first? The classic way works too:

```bash
git clone https://github.com/potaterrr/dotfiles.git ~/git-projects/dotfiles && cd ~/git-projects/dotfiles && chmod +x install.sh && ./install.sh
```

### Supported Distributions

The installer auto-detects and uses **apt** (Debian/Ubuntu), **dnf** (Fedora),
**pacman** (Arch), **zypper** (openSUSE), **apk** (Alpine), or **xbps** (Void).
On unsupported distros it warns, skips package installation, and still stows
the selected configs. Existing files that would collide (e.g. the distro's
default `~/.bashrc`) are backed up to `<file>.pre-stow.<timestamp>` first.

### Hyprland desktop (the `hypr` + `gtk` packages)

Modular config — `hyprland.conf` sources `conf/{monitors,theme,keybinds,autostart,input}.conf`.

**Idle management (`hypridle`)** — autostarts with Hyprland, each stage resets on any input:

| Idle | Action |
| :--- | :--- |
| 2 min | Brightness → 0% (black screen, no DPMS delay) |
| 10 min | Session locks (same Catppuccin hyprlock as `Super+L`) |
| 15 min | Display off (DPMS) |
| 25 min | Suspend — **on battery only** |
| 60 min | Suspend regardless of power source |

Power source is checked at timeout time (`/sys/class/power_supply/A*/online`), so
unplugging mid-session switches you to the aggressive schedule without a reload.
Every wake path restores brightness and lands directly on the hyprlock password
prompt. Media/video inhibitors (dbus) are respected. Caffeine mode (see the
`waybar` package below) pauses this entire schedule while active.

**Lock screen (`hyprlock`)** — Catppuccin Mocha palette with live clock (1s),
weekday + date label, and a battery/charging label (10s refresh).

**Cursor theme** — Bibata Modern Ice everywhere: `XCURSOR_THEME`/`XCURSOR_SIZE`
env vars for Hyprland, `gtk-cursor-theme-*` for GTK apps (see the `gtk` package).
`install.sh` tries the distro's Bibata package first, then falls back to the
official GitHub release tarball (user-level, `~/.local/share/icons/`).

**Task Manager (`potato-taskmgr`)** — a Windows-style task manager on
`Ctrl+Alt+Delete` (GTK3, reads `/proc` directly — no psutil). Live process table
(CPU%/memory/user/state, sortable + searchable), End Task with SIGTERM→SIGKILL
escalation, CPU/RAM/swap bars, and lock/logout/reboot/shutdown actions — all in
Catppuccin Mocha. `btop` moved to `Super+Shift+T`. Window rules in
`conf/windowrules.conf` use the Hyprland 0.53+ `match:class` syntax.

### Waybar status bar (the `waybar` package)

Catppuccin Mocha pill layout — workspaces/CPU/RAM/network on the left, clock in
the center, bluetooth/notifications/volume/battery/tray on the right.

**Caffeine mode (☕/💤)** — keeps the screen awake by holding a logind
`idle:sleep` inhibitor lock (a transient `caffeine.service` user unit), which
`hypridle` respects via `ignore_dbus_inhibit = false`. Toggle it with `Super+C`
or by clicking the bar icon:

| State | Icon | Meaning |
| :--- | :--- | :--- |
| Off | 💤 (dimmed) | Normal idle schedule runs |
| On | ☕ (teal, breathing glow) | All idle timers paused |

- Icon state syncs instantly (SIGRTMIN+8) no matter how caffeine is toggled —
  keybind, bar click, `make toggle`, or CLI.
- Auto-enabled at login (`exec-once` in `conf/autostart.conf`); each toggle
  sends a desktop notification.
- `install.sh` installs and daemon-reloads `caffeine.service` automatically
  whenever the `waybar` package is selected.
- Handy commands: `make -C ~/.config/waybar toggle` (also `on` / `off` /
  `status` / `install`).

### Fastfetch theming

The default `config.jsonc` is the [Catppuccin fastfetch](https://github.com/Nukecraft5419/fastfetch)
boxed layout (Hardware/Software sections) with a custom potato badge
(`logo/catppuccin_logo.png`, rendered via the kitty graphics protocol) and a
cute ASCII potato fallback (`potato.ans`, see `config-ascii.jsonc`). Piping
`fastfetch` (e.g. into `less`) automatically drops to the built-in fallback.

All colors are written as raw SGR parameters (`38;2;R;G;B`) instead of `#hex`:
mainline fastfetch accepts both, but some builds only parse SGR — so the theme
renders identically on every distro and build.

Other presets: `config-ascii.jsonc` (potato ASCII), `config-compact.jsonc`,
`config-pokemon.jsonc`, `config-v2.jsonc`.

Non-interactive options (great for fresh bare-metal installs):

```bash
./install.sh -y                     # default set: bash, nvim, starship, fastfetch
./install.sh -a                     # everything
PACKAGES="bash waybar" ./install.sh -y
./install.sh -p "bash hypr wofi"    # explicit list
./install.sh -h                     # all options
```

### Distro-agnostic package commands

The bash config detects your package manager at shell startup
(`~/.config/bash/15-package-manager.sh`) and exposes the same commands
everywhere — no more apt-only aliases:

| Command | Action |
| :--- | :--- |
| `update` | Refresh package lists + upgrade |
| `install <pkg>` | Install packages |
| `remove <pkg>` | Remove packages (with autoremove where applicable) |
| `search <term>` | Search repos |
| `pkg_update` / `pkg_install` / ... | Underlying functions, usable in scripts |

