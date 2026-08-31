# Fedora Niri + Noctalia Shell + Greeter Installer

Automated installer for **Niri** (scrollable-tiling Wayland compositor), **Noctalia** (native Wayland desktop shell v5), and **Noctalia Greeter** (`greetd` login screen) on Fedora Linux.

Curated preset adopting the clean **CachyOS/anxi0uz** minimalist tiling style with **Catppuccin** color theme.

---

## ⚡ Quick Install / Fresh Install (One-Line)

Jalankan perintah ini di terminal atau TTY:

```bash
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/install.sh?$(date +%s)" | bash
```

---

## 🌐 Install Brave Origin di Fedora

Untuk menginstall **Brave Origin** (minimalist standalone edition):

```bash
# 1-Line Installer Resmi Brave Origin:
curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin sh
```

*Atau via DNF Repository:*
```bash
sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo
sudo dnf install -y brave-origin
```

*(Untuk channel Nightly: `curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin CHANNEL=nightly sh` atau `sudo dnf install -y brave-origin-nightly`)*

---

## 🔄 Instant Force Apply & Reload (Live Session)

Jalankan perintah ini untuk membersihkan cache dan me-reload tampilan secara langsung:

```bash
rm -rf ~/.local/state/noctalia && curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/install.sh?$(date +%s)" | bash && noctalia msg config-reload 2>/dev/null; niri msg action load-config-file 2>/dev/null
```

---

## 🖥️ Layout & Aesthetics

1. **Single Top Bar:** Bar ramping (26px) di bagian atas layar untuk App Launcher, Workspaces, Active Window Title, Clock, Media, Volume, dan Quick Settings Control Center.
2. **Windows & Theme:** Catppuccin Mocha Dark theme, borderless active windows, window gaps 5px, sudut membulat 10px, soft shadows, dan spring physics animations.
3. **Pure Tiling:** Tanpa bottom dock untuk efisiensi ruang layar.

---

## ⌨️ Keybindings Reference

| Shortcut | Action |
|---|---|
| `Mod + Return` | Launch Terminal (**Alacritty**) |
| `Mod + B` | Launch Browser (**Brave Origin**) |
| `Mod + V` | Open Clipboard Manager (**Noctalia**) |
| `Mod + E` | Launch File Manager (**Yazi**) |
| `Mod + Space` / `Mod + Ctrl + Return` | App Launcher (Noctalia) |
| `Mod + S` | Control Center (Quick Settings) |
| `Mod + Shift + S` | Noctalia Settings |
| `Mod + Shift + Return` | Wallpaper Selector |
| `Mod + Escape` / `Mod + Shift + Q` | Power / Session Menu |
| `Mod + Alt + L` | Lock Screen |
| `Mod + Q` | Close Active Window |
| `Mod + T` | Toggle Floating Window |
| `Mod + F` | Maximize Column |
| `Mod + Shift + F` | Fullscreen Window |
| `Mod + H / J / K / L` | Focus Column Left / Down / Up / Right |
| `Mod + Ctrl + H / J / K / L` | Move Column Left / Down / Up / Right |
| `Mod + 1 .. 9` | Focus Workspace 1 – 9 |
| `Mod + Ctrl + 1 .. 9` | Move Column to Workspace 1 – 9 |
| `Mod + Shift + E` / `Ctrl + Alt + Del` | Quit Niri |
