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

# 2. Install Core System, Fonts, Audio, Portals, and Niri/Noctalia
log_info "Installing compositor, shell, fonts, and base multimedia stack..."
sudo dnf install -y --skip-unavailable \
    niri \
    greetd \
    accountsservice \
    xdg-desktop-portal \
    xdg-desktop-portal-gnome \
    xdg-desktop-portal-gtk \
    polkit \
    foot \
    pipewire \
    wireplumber \
    pipewire-pulseaudio \
    pipewire-alsa \
    brightnessctl \
    google-noto-sans-fonts \
    google-noto-color-emoji-fonts \
    fontawesome-fonts \
    mesa-dri-drivers \
    vulkan-loader

# Install Noctalia & Greeter packages
sudo dnf install -y --skip-unavailable noctalia noctalia-greeter 2>/dev/null || \
sudo dnf install -y --skip-unavailable noctalia-git noctalia-greeter 2>/dev/null || \
sudo dnf install -y --skip-unavailable noctalia || \
sudo dnf install -y --skip-unavailable noctalia-git

# 3. Configure Noctalia Shell (~/.config/noctalia/config.toml)
NOCTALIA_DIR="$HOME/.config/noctalia"
NOCTALIA_CONF="$NOCTALIA_DIR/config.toml"
mkdir -p "$NOCTALIA_DIR"

if [ ! -f "$NOCTALIA_CONF" ]; then
    log_info "Enabling Noctalia native polkit authentication agent..."
    cat << 'EOF' > "$NOCTALIA_CONF"
[shell]
polkit_agent = true
EOF
else
    if ! grep -q "polkit_agent" "$NOCTALIA_CONF"; then
        sed -i '/\[shell\]/a polkit_agent = true' "$NOCTALIA_CONF" 2>/dev/null || echo -e "\n[shell]\npolkit_agent = true" >> "$NOCTALIA_CONF"
    fi
fi

# 4. Configure Niri (~/.config/niri/config.kdl)
CONFIG_DIR="$HOME/.config/niri"
CONFIG_FILE="$CONFIG_DIR/config.kdl"
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_FILE" ]; then
    if [ -f /usr/share/niri/config.kdl ]; then
        log_info "Copying default niri config from /usr/share/niri/config.kdl..."
        cp /usr/share/niri/config.kdl "$CONFIG_FILE"
    else
        touch "$CONFIG_FILE"
    fi
fi

# Inject Noctalia settings if not present
if ! grep -q 'spawn-at-startup "noctalia"' "$CONFIG_FILE"; then
    log_info "Injecting Noctalia autostart and rules into $CONFIG_FILE..."
    cat << 'EOF' >> "$CONFIG_FILE"

// --- Noctalia Integration ---
spawn-at-startup "noctalia"

binds {
    Mod+Space { spawn-sh "noctalia msg panel-toggle launcher"; }
    Mod+S { spawn-sh "noctalia msg panel-toggle control-center"; }
    Mod+Comma { spawn-sh "noctalia msg settings-toggle"; }
    Alt+Tab { spawn-sh "noctalia msg window-switcher"; }

    XF86AudioRaiseVolume { spawn-sh "noctalia msg volume-up"; }
    XF86AudioLowerVolume { spawn-sh "noctalia msg volume-down"; }
    XF86AudioMute { spawn-sh "noctalia msg volume-mute"; }
    XF86MonBrightnessUp { spawn-sh "noctalia msg brightness-up"; }
    XF86MonBrightnessDown { spawn-sh "noctalia msg brightness-down"; }
}

window-rule {
    match app-id="dev.noctalia.Noctalia"
    open-floating true
    default-column-width { fixed 1080; }
    default-window-height { fixed 920; }
}

layer-rule {
    match namespace="^noctalia-backdrop"
    place-within-backdrop true
}

debug {
    honor-xdg-activation-with-invalid-serial
}
// -----------------------------
EOF
    log_success "Noctalia rules appended to config.kdl"
else
    log_info "Noctalia configuration already present in config.kdl, skipping injection."
fi

# 5. Configure Greetd + Noctalia Greeter
if command -v noctalia-greeter-session &>/dev/null || [ -f /usr/bin/noctalia-greeter-session ]; then
    log_info "Configuring greetd for Noctalia Greeter..."
    GREETER_BIN=$(command -v noctalia-greeter-session 2>/dev/null || echo "/usr/bin/noctalia-greeter-session")
    
    sudo mkdir -p /var/lib/noctalia-greeter
    if id "greeter" &>/dev/null; then
        sudo chown -R greeter:greeter /var/lib/noctalia-greeter
    fi

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

    log_info "Enabling greetd service..."
    for dm in gdm sddm lightdm; do
        if systemctl is-enabled --quiet $dm.service 2>/dev/null; then
            log_warn "Disabling $dm.service..."
            sudo systemctl disable $dm.service
        fi
    done
    sudo systemctl enable greetd.service
    log_success "greetd.service enabled."
else
    log_warn "noctalia-greeter-session binary not found in PATH; skipping greetd auto-activation."
fi

# 6. Verification
if command -v niri &>/dev/null; then
    niri validate 2>/dev/null && log_success "Niri config validation passed." || log_warn "Niri config syntax check returned warnings."
fi

echo ""
log_success "Installation & configuration complete!"
echo -e "Reboot or start ${GREEN}greetd${NC} to enter your Noctalia login screen."
