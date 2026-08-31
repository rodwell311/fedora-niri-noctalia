# Fedora Niri + Noctalia Shell + Greeter Installer

Automated installer for **Niri** (scrollable-tiling Wayland compositor), **Noctalia** (native Wayland desktop shell v5), and **Noctalia Greeter** (`greetd` login screen) on Fedora Linux.

---

## ⚡ Quick Install (One-Line)

Jalankan perintah ini di terminal / TTY:

```bash
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/install.sh?$(date +%s)" | bash
```

---

## 🔄 Instant Update / Apply Config (Live Session)

Jika sudah terinstall dan ingin langsung refresh/apply konfigurasi terbaru tanpa reboot:

```bash
rm -f ~/.local/state/noctalia/settings.toml && curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/install.sh?$(date +%s)" | bash && noctalia msg restart 2>/dev/null; niri msg action reload-config 2>/dev/null
```

---

## ✨ Fitur & Konfigurasi Curation

1. **Top Bar (Ultra-Slim Minimalist):**
   * Ketebalan 24px (`thickness = 24`), flush margin atas layar.
   * Pill/capsule layout semi-transparan (`surface_variant`).
   * Widget lengkap: Workspaces, Active Window, Clock, Media, Volume, Brightness, Network, Battery, Control Center.
   * Scroll mouse pada bar untuk atur volume; klik kanan untuk Control Center.

2. **Window & Layout (Borderless):**
   * **Borderless active window** (tanpa garis/focus ring yang mengganggu).
   * Corner radius subtle **10px** (`geometry-corner-radius 10` + `clip-to-geometry`).
   * Native Wayland blur aktif untuk floating panels, overview, dan backdrop.

3. **Shortcuts & Terminal:**
   * Terminal default: **Alacritty** (`Mod + Return` atau `Mod + T`).
   * File Manager: **Yazi** (`Mod + E`).
   * App Launcher: `Mod + Space`.
   * Control Center: `Mod + S`.
   * Noctalia Settings: `Mod + ,` (koma).
   * Close Window: `Mod + Q`.
   * Floating Window Toggle: `Mod + V`.
   * Navigasi: `Mod + H/J/K/L` atau Arrow Keys; Workspace: `Mod + 1..5`.

4. **Greetd & Login Screen:**
   * Menggunakan **Noctalia Greeter** terintegrasi dengan wallpaper dan color sync.
   * Otomatis disable GDM/SDDM lama dan mengaktifkan `greetd.service` + `graphical.target`.
