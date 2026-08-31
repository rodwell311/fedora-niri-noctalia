#!/usr/bin/env bash
set -e

# ==============================================================================
# Installer: Niri + Noctalia Shell on Fedora
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

# 1. Update and install Niri
log_info "Installing Niri and core Wayland tools..."
sudo dnf install -y niri xdg-desktop-portal-gnome polkit-gnome foot

# 2. Install Noctalia
log_info "Installing Noctalia Shell..."
if [ "$FEDORA_VERSION" -ge 44 ] 2>/dev/null; then
    sudo dnf install -y noctalia
else
    log_info "Enabling Copr repository for Noctalia..."
    # Attempt standard copr enable; fallback to direct repo URL if CDN/Anubis blocks
    if ! sudo dnf copr enable -y lionheartp/Hyprland; then
        log_warn "Standard Copr enable failed. Adding repository directly..."
        sudo curl -fsSL "https://download.copr.fedorainfracloud.org/results/lionheartp/Hyprland/fedora-${FEDORA_VERSION}-\$basearch/lionheartp-Hyprland-fedora-${FEDORA_VERSION}.repo" \
            -o "/etc/yum.repos.d/_copr_lionheartp-Hyprland.repo"
    fi
    sudo dnf install -y noctalia-git || sudo dnf install -y noctalia
fi

# 3. Configure Niri (~/.config/niri/config.kdl)
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

# 4. Verification
if command -v niri &>/dev/null; then
    niri validate 2>/dev/null && log_success "Niri config validation passed." || log_warn "Niri config syntax check returned warnings."
fi

echo ""
log_success "Installation complete!"
echo -e "You can now log in to the ${GREEN}Niri${NC} session from your display manager or run ${GREEN}niri${NC} from TTY."
