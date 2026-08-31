# Fedora Niri + Noctalia Shell + Greeter Installer

Automated installer for **Niri** (scrollable-tiling Wayland compositor), **Noctalia** (native Wayland desktop shell v5), and **Noctalia Greeter** (`greetd` login screen) on Fedora Linux.

Curated preset adopting the sleek, minimal **CachyOS / anxi0uz** dotfiles style with **Tokyo-Night / Catppuccin** color theme.

---

## ⚡ Quick Install / Fresh Install (One-Line)

Jalankan perintah ini di terminal atau TTY:

```bash
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/install.sh?$(date +%s)" | bash
```

---

## 🔄 Instant Force Apply & Reload (Live Session)

Jalankan perintah satu baris ini untuk membersihkan cache state dan me-reload Noctalia & Niri secara paksa:

```bash
rm -rf ~/.local/state/noctalia && curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/install.sh?$(date +%s)" | bash && killall -9 noctalia 2>/dev/null; nohup noctalia >/dev/null 2>&1 & niri msg action reload-config 2>/dev/null
```

---

## ⌨️ Keybindings Reference

| Shortcut | Action |
|---|---|
| `Mod + Return` | Launch Terminal (**Alacritty**) |
| `Mod + B` | Launch Browser (**Firefox**) |
| `Mod + E` | Launch File Manager (**Yazi**) |
| `Mod + Space` / `Mod + Ctrl + Return` | App Launcher (Noctalia) |
| `Mod + S` | Control Center (Quick Settings) |
| `Mod + Shift + S` | Noctalia Settings |
| `Mod + Shift + Return` | Wallpaper Selector |
| `Mod + Shift + Q` | Power / Session Menu |
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
