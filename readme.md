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
| **`fastfetch`** | Fastfetch system info presets (compact, groups, pokemon) |
| **`hypr`** | Hyprland dynamic tiling window manager setup |
| **`waybar`** | Custom Waybar status bar layout |
| **`wofi`** | Wofi application launcher configuration |

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

