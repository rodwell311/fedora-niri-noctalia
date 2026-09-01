#!/usr/bin/env bash
set -e

# ==============================================================================
# Installer: Niri + Noctalia Shell + Noctalia Greeter on Fedora
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

# 1. Setup Repositories based on Fedora Version
if [ "$FEDORA_VERSION" -ge 44 ] 2>/dev/null; then
    log_info "Fedora 44+ detected: 'niri' and 'noctalia' are in official repos."
    enable_copr "lionheartp/Hyprland"
else
    log_info "Fedora < 44 detected: enabling upstream Copr repositories..."
    enable_copr "yalter/niri"
    enable_copr "lionheartp/Hyprland"
fi

# 2. Install Core System, Fonts, Audio, Portals, Zsh, and Niri/Noctalia
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
    zsh \
    zsh-autosuggestions \
    zsh-syntax-highlighting \
    util-linux-user \
    fuse \
    fuse-libs \
    fontawesome-fonts \
    mesa-dri-drivers \
    vulkan-loader

# Install Noctalia & Greeter packages
sudo dnf install -y --skip-unavailable noctalia noctalia-greeter 2>/dev/null || \
sudo dnf install -y --skip-unavailable noctalia-git noctalia-greeter 2>/dev/null || \
sudo dnf install -y --skip-unavailable noctalia || \
sudo dnf install -y --skip-unavailable noctalia-git

# 3. Deploy Alacritty Config (~/.config/alacritty/alacritty.toml)
log_info "Installing comprehensive fonts (CJK, Emoji, Symbols, International Scripts)..."
sudo dnf install -y \
    google-noto-sans-cjk-fonts \
    google-noto-serif-cjk-fonts \
    google-noto-color-emoji-fonts \
    google-noto-sans-symbols-fonts \
    google-noto-sans-symbols-2-fonts \
    google-noto-sans-arabic-fonts \
    google-noto-sans-devanagari-fonts \
    google-noto-sans-thai-fonts \
    google-noto-sans-khmer-fonts \
    google-noto-sans-myanmar-fonts \
    fira-code-fonts \
    jetbrains-mono-fonts \
    xdg-user-dirs 2>/dev/null || true

ALACRITTY_DIR="$HOME/.config/alacritty"
mkdir -p "$ALACRITTY_DIR"
log_info "Deploying CachyOS/Catppuccin styled Alacritty configuration..."
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/alacritty.toml?$(date +%s)" -o "$ALACRITTY_DIR/alacritty.toml"
log_success "Alacritty configuration deployed."

# 4. Deploy Zsh and Starship Prompt Configurations
log_info "Setting up Starship prompt and Zsh environment..."
if ! command -v starship &>/dev/null; then
    curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"
# Deploy Zsh & Starship Configurations
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/zshrc?$(date +%s)" -o "$HOME/.zshrc"
mkdir -p "$HOME/.config/fastfetch"
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/fastfetch-config.jsonc?$(date +%s)" -o "$HOME/.config/fastfetch/config.jsonc"
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/starship.toml?$(date +%s)" -o "$HOME/.config/starship.toml"
log_success "Zsh & Starship configuration deployed."

# 5. Deploy Curated Noctalia Config (~/.config/noctalia/config.toml)
NOCTALIA_DIR="$HOME/.config/noctalia"
NOCTALIA_CONF="$NOCTALIA_DIR/config.toml"
mkdir -p "$NOCTALIA_DIR/palettes"

# Clear entire cached GUI state overrides
rm -rf "$HOME/.local/state/noctalia" 2>/dev/null || true

log_info "Deploying custom high-contrast Catppuccin palette..."
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/CatppuccinCustom.json?$(date +%s)" -o "$NOCTALIA_DIR/palettes/CatppuccinCustom.json"

log_info "Deploying Tokyo-Night Noctalia configuration..."
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/noctalia-config.toml?$(date +%s)" -o "$NOCTALIA_CONF"
log_success "Curated Noctalia config.toml deployed."

# 5. Deploy Curated Niri Config (~/.config/niri/config.kdl)
CONFIG_DIR="$HOME/.config/niri"
CONFIG_FILE="$CONFIG_DIR/config.kdl"
mkdir -p "$CONFIG_DIR"

log_info "Deploying CachyOS/anxi0uz Niri configuration..."
curl -fsSL "https://raw.githubusercontent.com/rodwell311/fedora-niri-noctalia/main/config.kdl?$(date +%s)" -o "$CONFIG_FILE"
log_success "Curated Niri config.kdl deployed."

# 6. Configure macOS (WhiteSur) Icon Theme & User Directories
log_info "Installing macOS WhiteSur icon theme and setting up directories..."
if [ ! -d "$HOME/.local/share/icons/WhiteSur-dark" ]; then
    rm -rf /tmp/whitesur-icons
    git clone --depth=1 https://github.com/vinceliuice/WhiteSur-icon-theme.git /tmp/whitesur-icons
    cd /tmp/whitesur-icons && ./install.sh -d "$HOME/.local/share/icons" -t default -a
    rm -rf /tmp/whitesur-icons
    cd "$HOME"
fi

gsettings set org.gnome.desktop.interface icon-theme 'WhiteSur-dark'

mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
cat << 'EOF' > "$HOME/.config/gtk-3.0/settings.ini"
[Settings]
gtk-icon-theme-name=WhiteSur-dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF

cat << 'EOF' > "$HOME/.config/gtk-4.0/settings.ini"
[Settings]
gtk-icon-theme-name=WhiteSur-dark
gtk-theme-name=Adwaita-dark
gtk-application-prefer-dark-theme=1
EOF

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

if command -v gio &>/dev/null; then
    gio set -t stringv "$HOME/Documents" metadata::custom-icon "folder-documents" 2>/dev/null || true
    gio set -t stringv "$HOME/Downloads" metadata::custom-icon "folder-download" 2>/dev/null || true
    gio set -t stringv "$HOME/Music" metadata::custom-icon "folder-music" 2>/dev/null || true
    gio set -t stringv "$HOME/Pictures" metadata::custom-icon "folder-pictures" 2>/dev/null || true
    gio set -t stringv "$HOME/Videos" metadata::custom-icon "folder-videos" 2>/dev/null || true
    gio set -t stringv "$HOME/Templates" metadata::custom-icon "folder-templates" 2>/dev/null || true
    gio set -t stringv "$HOME/Public" metadata::custom-icon "folder-publicshare" 2>/dev/null || true
    gio set -t stringv "$HOME/Desktop" metadata::custom-icon "user-desktop" 2>/dev/null || true
fi

# 7. Configure Greetd + Noctalia Greeter
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
else
    log_warn "noctalia-greeter-session binary not found in PATH; skipping greetd auto-activation."
fi

# 7. Polkit Rule for NetworkManager (Allow Wi-Fi scanning & control without password prompts)
log_info "Configuring Polkit rule for NetworkManager..."
sudo tee /etc/polkit-1/rules.d/50-networkmanager.rules > /dev/null << 'EOF'
polkit.addRule(function(action, subject) {
    if (action.id.indexOf("org.freedesktop.NetworkManager.") == 0 && subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF
log_success "Polkit NetworkManager rule created."

# 8. Verification & Live Restart
if command -v niri &>/dev/null; then
    niri validate 2>/dev/null && log_success "Niri config validation passed." || log_warn "Niri config syntax check returned warnings."
fi

if [ -n "$WAYLAND_DISPLAY" ]; then
    killall -9 noctalia 2>/dev/null || pkill -x noctalia 2>/dev/null || true
    nohup noctalia >/dev/null 2>&1 &
    niri msg action reload-config 2>/dev/null || true
fi

echo ""
log_success "Installation & configuration complete!"
