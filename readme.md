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
Clone the repository and launch the automated setup script instantly:

```bash
git clone https://github.com/potaterrr/dotfiles.git ~/git-projects/dotfiles && cd ~/git-projects/dotfiles && chmod +x install.sh && ./install.sh
```

