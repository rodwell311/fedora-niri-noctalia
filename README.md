# Fedora Niri + Noctalia Shell Installer

Automated installer for **Niri** (scrollable-tiling Wayland compositor) and **Noctalia** (native Wayland desktop shell) on Fedora.

## Quick Install (One-Line)

```bash
curl -fsSL https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/install.sh | bash
```

## What it does
1. Detects Fedora version.
2. Installs `niri`, `xdg-desktop-portal-gnome`, `polkit-gnome`, and `foot`.
3. Installs `noctalia` (via official repos on Fedora 44+, or Copr repo on Fedora 40-43).
4. Configures `~/.config/niri/config.kdl` with Noctalia autostart, IPC shortcuts, and floating window rules.
5. Validates the generated Niri configuration.
