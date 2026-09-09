# 🥔 Potato Rice (.config)

A minimalist, high-performance Linux dotfiles configuration built around **Debian Trixie**, styled in **Catppuccin Mocha**, and powered by high-starch energy.

![Potato Mode](https://img.shields.io/badge/Theme-Catppuccin%20Mocha-1e1e2e?style=flat-square&logo=catppuccin&logoColor=f9e2af)
![OS](https://img.shields.io/badge/OS-Debian%20Trixie-a81d33?style=flat-square&logo=debian&logoColor=white)
![Window Manager](https://img.shields.io/badge/WM-Wayland-blue?style=flat-square&logo=wayland&logoColor=white)

---

## ✨ Features

- **Custom Potato Branding**: Custom high-resolution vector potato asset (`potato.svg`) integrated seamlessly into `wlogout`.
- **Catppuccin Mocha Palette**: A cohesive, relaxing dark color scheme applied across all system menus and bars.
- **Optimized Ecosystem**: Cleaned-up, lightweight configuration directory strictly tailored for maximum speed and zero bloat.

---

## 📂 Configuration Layout

```text
~/.config/
├── alacritty/           # Fast, GPU-accelerated terminal emulator
├── hypr/                # Wayland dynamic tiling window manager
├── kitty/               # Alternative terminal configuration
├── mako/                # Lightweight Wayland notification daemon
├── nvim/                # Neovim modern text editor setup
├── swaylock/            # Screen locker with matching aesthetic
├── swaync/              # Control center & notification daemon
├── waybar/              # Highly customizable status bar
├── wlogout/             # Custom power menu with crisp vector potato
└── wofi/                # Application launcher and menu
```

---

## 🚀 Highlights & Customizations

### 🥔 wlogout Potato Power Menu
The system power menu (`wlogout`) features a custom vector-drawn potato icon that scales cleanly at any resolution with smooth CSS hover feedback and animations.

```css
#potato {
    background-image: url("icons/potato.svg");
    background-size: 42px;
    background-position: center 25%;
    background-repeat: no-repeat;
}
```

---

## 🛠️ Requirements & Tools

- **OS**: Debian Trixie / Wayland environment
- **Compositor**: Hyprland
- **Bar**: Waybar
- **Launcher**: Wofi
- **Power Menu**: wlogout

---

## 📜 License
Distributed under the MIT License. Feel free to fork, steal, or adapt parts for your own setup!
