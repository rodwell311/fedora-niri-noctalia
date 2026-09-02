#!/usr/bin/env bash
set -e

# ==============================================================================
# Dotfiles Installer: Niri + Noctalia Shell + macOS Aesthetics on Fedora
# (Compatible with Fedora Workstation, Silverblue, & Fedora Everything Minimal)
# ==============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

if [ ! -f /etc/fedora-release ]; then
    log_error "This script is intended for Fedora Linux only."
    exit 1
fi

FEDORA_VERSION=$(rpm -E %fedora 2>/dev/null || grep -oP '(?<=VERSION_ID=)[0-9]+' /etc/os-release)
log_info "Detected Fedora release: ${FEDORA_VERSION}"

# Determine dotfiles root directory (local cloned repo or remote raw download)
DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
RAW_URL="https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main"

fetch_file() {
    local src="$1"
    local dest="$2"
    mkdir -p "$(dirname "$dest")"
    if [ -f "$DOTFILES_DIR/$src" ]; then
        cp -r "$DOTFILES_DIR/$src" "$dest"
    else
        curl -fsSL "${RAW_URL}/${src}?$(date +%s)" -o "$dest"
    fi
}

# Helper to enable Copr safely with CDN fallback
enable_copr() {
    local copr_name="$1"
    local repo_user="${copr_name%%/*}"
    local repo_project="${copr_name##*/}"
    
    log_info "Enabling Copr repository: ${copr_name}..."
    if ! sudo dnf copr enable -y "${copr_name}" 2>/dev/null; then
        log_warn "Standard Copr enable for ${copr_name} failed. Using direct CDN repo fallback..."
        sudo curl -fsSL "https://copr.fedorainfracloud.org/coprs/${repo_user}/${repo_project}/repo/fedora-${FEDORA_VERSION}/${repo_user}-${repo_project}-fedora-${FEDORA_VERSION}.repo" \
            -o "/etc/yum.repos.d/_copr_${repo_user}-${repo_project}.repo" || true
    fi
}

# 1. Setup Repositories
if [ "$FEDORA_VERSION" -ge 44 ] 2>/dev/null; then
    log_info "Fedora 44+ detected: 'niri' and 'noctalia' are in official repos."
    enable_copr "lionheartp/Hyprland"
else
    log_info "Fedora < 44 detected: enabling upstream Copr repositories..."
    enable_copr "yalter/niri"
    enable_copr "lionheartp/Hyprland"
fi

# 2. Install Core System, Audio, Portals, Shell, Fonts, and Utilities
log_info "Installing compositor, shell, fonts, and base multimedia stack..."
sudo dnf install -y --skip-unavailable \
    niri \
    greetd \
    accountsservice \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    polkit \
    alacritty \
    foot \
    pipewire \
    wireplumber \
    pipewire-pulseaudio \
    pipewire-alsa \
    brightnessctl \
    swayidle \
    swaylock \
    google-noto-sans-fonts \
    google-noto-color-emoji-fonts \
    google-noto-sans-cjk-fonts \
    google-noto-serif-cjk-fonts \
    google-noto-sans-symbols-fonts \
    google-noto-sans-symbols-2-fonts \
    google-noto-sans-arabic-fonts \
    google-noto-sans-devanagari-fonts \
    google-noto-sans-thai-fonts \
    google-noto-sans-khmer-fonts \
    google-noto-sans-myanmar-fonts \
    fira-code-fonts \
    jetbrains-mono-fonts \
    fastfetch \
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    util-linux-user \
    fuse \
    fuse-libs \
    xdg-user-dirs \
    nautilus \
    fontawesome-fonts \
    mesa-dri-drivers \
    vulkan-loader

# Install Noctalia & Greeter packages
sudo dnf install -y --skip-unavailable noctalia noctalia-greeter 2>/dev/null || \
sudo dnf install -y --skip-unavailable noctalia-git noctalia-greeter 2>/dev/null || \
sudo dnf install -y --skip-unavailable noctalia || \
sudo dnf install -y --skip-unavailable noctalia-git

# 3. Install Brave Origin Browser if not installed
if ! command -v brave-origin &>/dev/null && ! command -v brave-browser &>/dev/null; then
    log_info "Installing Brave Origin..."
    curl -fsS https://dl.brave.com/install.sh | FLAVOR=origin sh || true
fi

# 4. Deploy Apple SF Pro & SF Mono Fonts
log_info "Installing Apple SF Pro and SF Mono fonts..."
mkdir -p "$HOME/.local/share/fonts/SF-Pro" "$HOME/.local/share/fonts/SF-Mono"
if [ ! -f "$HOME/.local/share/fonts/SF-Pro/SF-Pro-Display-Regular.otf" ]; then
    curl -fSL "https://raw.githubusercontent.com/sahibjotsaggu/San-Francisco-Pro-Fonts/master/SF-Pro-Display-Regular.otf" -o "$HOME/.local/share/fonts/SF-Pro/SF-Pro-Display-Regular.otf"
    curl -fSL "https://raw.githubusercontent.com/sahibjotsaggu/San-Francisco-Pro-Fonts/master/SF-Pro-Display-Medium.otf" -o "$HOME/.local/share/fonts/SF-Pro/SF-Pro-Display-Medium.otf"
    curl -fSL "https://raw.githubusercontent.com/sahibjotsaggu/San-Francisco-Pro-Fonts/master/SF-Pro-Display-Semibold.otf" -o "$HOME/.local/share/fonts/SF-Pro/SF-Pro-Display-Semibold.otf"
    curl -fSL "https://raw.githubusercontent.com/sahibjotsaggu/San-Francisco-Pro-Fonts/master/SF-Pro-Display-Bold.otf" -o "$HOME/.local/share/fonts/SF-Pro/SF-Pro-Display-Bold.otf"
    curl -fSL "https://raw.githubusercontent.com/sahibjotsaggu/San-Francisco-Pro-Fonts/master/SF-Pro-Text-Regular.otf" -o "$HOME/.local/share/fonts/SF-Pro/SF-Pro-Text-Regular.otf"
    curl -fSL "https://raw.githubusercontent.com/sahibjotsaggu/San-Francisco-Pro-Fonts/master/SF-Pro-Text-Medium.otf" -o "$HOME/.local/share/fonts/SF-Pro/SF-Pro-Text-Medium.otf"
    curl -fSL "https://raw.githubusercontent.com/sahibjotsaggu/San-Francisco-Pro-Fonts/master/SF-Pro-Text-Semibold.otf" -o "$HOME/.local/share/fonts/SF-Pro/SF-Pro-Text-Semibold.otf"
    curl -fSL "https://raw.githubusercontent.com/sahibjotsaggu/San-Francisco-Pro-Fonts/master/SF-Pro-Text-Bold.otf" -o "$HOME/.local/share/fonts/SF-Pro/SF-Pro-Text-Bold.otf"
fi

if [ ! -f "$HOME/.local/share/fonts/SF-Mono/SF-Mono-Regular.otf" ]; then
    rm -rf /tmp/sf-mono && git clone --depth=1 https://github.com/ZulwiyozaPutra/SF-Mono-Font.git /tmp/sf-mono 2>/dev/null || true
    cp /tmp/sf-mono/*.otf "$HOME/.local/share/fonts/SF-Mono/" 2>/dev/null || true
    rm -rf /tmp/sf-mono
fi
fc-cache -f "$HOME/.local/share/fonts"

# 5. Deploy WhiteSur Icon Theme & macOS Cursor Theme
log_info "Installing WhiteSur icon theme and macOS cursor..."
mkdir -p "$HOME/.local/share/icons" "$HOME/.icons"
if [ ! -d "$HOME/.local/share/icons/WhiteSur-dark" ]; then
    rm -rf /tmp/whitesur-icons
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/whitesur-icons
    cd /tmp/whitesur-icons && ./install.sh -d "$HOME/.local/share/icons" -t default -a
    rm -rf /tmp/whitesur-icons
    cd "$HOME"
fi

if [ ! -d "$HOME/.local/share/icons/macOS" ]; then
    curl -fSL "https://github.com/ful1e5/apple_cursor/releases/download/v2.0.1/macOS.tar.xz" -o /tmp/macOS.tar.xz
    tar -xJf /tmp/macOS.tar.xz -C "$HOME/.local/share/icons/"
    tar -xJf /tmp/macOS.tar.xz -C "$HOME/.icons/" 2>/dev/null || true
    rm -f /tmp/macOS.tar.xz
fi

# 6. Deploy Wallpapers and Profile Avatar
log_info "Deploying wallpapers and avatars to ~/Pictures/walls/..."
mkdir -p "$HOME/Pictures/walls"
fetch_file "pictures/walls/wallpaper.png" "$HOME/Pictures/walls/26668334.png"
fetch_file "pictures/walls/avatar.jpg" "$HOME/Pictures/walls/hiyuki_profile.jpg"

# 7. Deploy Starship Prompt & Shell Configurations
log_info "Setting up Starship prompt and Zsh environment..."
if ! command -v starship &>/dev/null; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
fi

fetch_file ".zshrc" "$HOME/.zshrc"
fetch_file ".config/starship.toml" "$HOME/.config/starship.toml"
fetch_file ".config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"

# Set default shell to Zsh for current user
if [ "$SHELL" != "$(which zsh)" ]; then
    chsh -s "$(which zsh)" "$USER" 2>/dev/null || true
fi

# 8. Deploy Dotfiles (.config)
log_info "Deploying config files..."
fetch_file ".config/niri/config.kdl" "$HOME/.config/niri/config.kdl"
fetch_file ".config/noctalia/config.toml" "$HOME/.config/noctalia/config.toml"
fetch_file ".config/noctalia/icons/fedora.svg" "$HOME/.config/noctalia/icons/fedora.svg"
fetch_file ".config/noctalia/palettes/CatppuccinCustom.json" "$HOME/.config/noctalia/palettes/CatppuccinCustom.json"
fetch_file ".config/alacritty/alacritty.toml" "$HOME/.config/alacritty/alacritty.toml"
fetch_file ".config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
fetch_file ".config/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"
fetch_file ".local/state/noctalia/settings.toml" "$HOME/.local/state/noctalia/settings.toml"

# 9. Set GNOME / GTK System Settings
gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'
gsettings set org.gnome.desktop.interface cursor-theme 'macOS'
gsettings set org.gnome.desktop.interface cursor-size 22
gsettings set org.gnome.desktop.interface font-name 'SF Pro Display 11'
gsettings set org.gnome.desktop.interface document-font-name 'SF Pro Text 11'
gsettings set org.gnome.desktop.interface monospace-font-name 'SF Mono 11'

mkdir -p "$HOME/.icons/default"
cat << 'EOF' > "$HOME/.icons/default/index.theme"
[Icon Theme]
Name=Default
Comment=Default Cursor Theme
Inherits=macOS
EOF

# 10. Configure User Directories
log_info "Setting up XDG user directories and icons..."
mkdir -p "$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads" "$HOME/Music" "$HOME/Pictures" "$HOME/Videos" "$HOME/Templates" "$HOME/Public"

printf "%s\n" \
    "XDG_DESKTOP_DIR=\"\$HOME/Desktop\"" \
    "XDG_DOWNLOAD_DIR=\"\$HOME/Downloads\"" \
    "XDG_TEMPLATES_DIR=\"\$HOME/Templates\"" \
    "XDG_PUBLICSHARE_DIR=\"\$HOME/Public\"" \
    "XDG_DOCUMENTS_DIR=\"\$HOME/Documents\"" \
    "XDG_MUSIC_DIR=\"\$HOME/Music\"" \
    "XDG_PICTURES_DIR=\"\$HOME/Pictures\"" \
    "XDG_VIDEOS_DIR=\"\$HOME/Videos\"" > "$HOME/.config/user-dirs.dirs"

# 11. Configure Greetd + Noctalia Greeter
if command -v noctalia-greeter-session &>/dev/null || [ -f /usr/bin/noctalia-greeter-session ]; then
    log_info "Configuring greetd for Noctalia Greeter..."
    GREETER_BIN=$(command -v noctalia-greeter-session 2>/dev/null || echo "/usr/bin/noctalia-greeter-session")
    
    if ! id "greeter" &>/dev/null; then
        sudo useradd -r -M -G video,input,render -s /sbin/nologin greeter 2>/dev/null || true
    else
        sudo usermod -aG video,input,render greeter 2>/dev/null || true
    fi

    sudo mkdir -p /var/lib/noctalia-greeter
    sudo chown -R greeter:greeter /var/lib/noctalia-greeter 2>/dev/null || true

    sudo mkdir -p /etc/greetd
    if [ -f /etc/greetd/config.toml ]; then
        sudo cp /etc/greetd/config.toml /etc/greetd/config.toml.bak
    fi

    sudo tee /etc/greetd/config.toml > /dev/null << EOF
[terminal]
vt = 1

[default_session]
command = "${GREETER_BIN}"
user = "greeter"
EOF
    log_success "Greetd configured to use Noctalia Greeter (${GREETER_BIN})"

    sudo systemctl enable accounts-daemon.service 2>/dev/null || true
    sudo systemctl set-default graphical.target 2>/dev/null || true

    log_info "Enabling greetd service..."
    for dm in gdm sddm lightdm; do
        if systemctl is-enabled --quiet $dm.service 2>/dev/null; then
            log_warn "Disabling $dm.service..."
            sudo systemctl disable $dm.service
        fi
    done
    sudo systemctl enable greetd.service
    log_success "greetd.service enabled with graphical.target default."
fi

# 12. Polkit Rule for NetworkManager (Allow Wi-Fi scanning & control without password prompts)
log_info "Configuring Polkit rule for NetworkManager..."
sudo tee /etc/polkit-1/rules.d/50-networkmanager.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
log_success "Polkit NetworkManager rule created."

# 13. Verification & Live Restart
if command -v niri &>/dev/null; then
    niri validate 2>/dev/null && log_success "Niri config validation passed." || log_warn "Niri config syntax check returned warnings."
fi

if [ -n "$WAYLAND_DISPLAY" ]; then
    killall -9 noctalia 2>/dev/null || pkill -x noctalia 2>/dev/null || true
    nohup noctalia >/dev/null 2>&1 &
    niri msg action reload-config 2>/dev/null || true
fi

echo ""
log_success "Dotfiles setup complete! All desktop configurations, wallpapers, and styles are applied."