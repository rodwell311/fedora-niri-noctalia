# Fedora Niri + Noctalia Shell + Greeter Installer

Automated installer for **Niri** (scrollable-tiling Wayland compositor), **Noctalia** (native Wayland desktop shell), and **Noctalia Greeter** (`greetd` login screen) on Fedora.

## Quick Install (One-Line)

```bash
curl -fsSL https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/install.sh | bash
```

## What it does
1. **System & Deps:** Detects Fedora version and installs `niri`, `greetd`, `accountsservice`, `xdg-desktop-portal-gnome`, `polkit-gnome`, and `foot`.
2. **Noctalia Ecosystem:** Installs `noctalia` and `noctalia-greeter` (via official Fedora repo or Copr `lionheartp/Hyprland`).
3. **Niri Integration:** Configures `~/.config/niri/config.kdl` with Noctalia autostart, IPC shortcuts (`Mod+Space`, `Mod+S`, etc.), and layer rules.
4. **Display Manager:** Configures `/etc/greetd/config.toml` to launch `noctalia-greeter-session`, disables legacy display managers (GDM/SDDM), and enables `greetd.service`.
5. **Validation:** Runs `niri validate` to ensure config syntax correctness.
