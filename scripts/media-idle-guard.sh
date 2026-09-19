#!/usr/bin/env bash
# ==============================================================================
# media-idle-guard.sh — Smart media-aware idle & sleep guard for Niri & Wayland
#
# Rules:
# 1. No media playing -> swayidle-idle ON (lock 5m, DPMS 6m), swayidle-sleep ON (suspend 15m).
# 2. Media playing (AUDIO) -> swayidle-idle ON (lock 5m, DPMS 6m), swayidle-sleep OFF (no suspend).
# 3. Media playing (VIDEO focused/fullscreen) -> swayidle-idle OFF (no lock/DPMS), swayidle-sleep OFF (no suspend).
# ==============================================================================

set -u

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

resolve_niri_env() {
    if [[ -z "${NIRI_SOCKET:-}" ]]; then
        local sock
        sock=$(ls "$XDG_RUNTIME_DIR"/niri.*.sock 2>/dev/null | head -1)
        if [[ -n "$sock" ]]; then
            export NIRI_SOCKET="$sock"
        fi
    fi
    if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
        local wl
        wl=$(ls "$XDG_RUNTIME_DIR"/wayland-* 2>/dev/null | head -1 | xargs -n1 basename 2>/dev/null)
        if [[ -n "$wl" ]]; then
            export WAYLAND_DISPLAY="$wl"
        fi
    fi
}

current_mode=""

cleanup() {
    echo "[media-idle-guard] Stopping guard, restoring default idle & sleep services..."
    systemctl --user start swayidle-idle.service swayidle-sleep.service 2>/dev/null || true
    exit 0
}
trap cleanup SIGTERM SIGINT SIGHUP

echo "[media-idle-guard] Service started, monitoring MPRIS & Niri state..."

while true; do
    resolve_niri_env

    # 1. Gather all MPRIS players
    mapfile -t players < <(playerctl -l 2>/dev/null || true)

    has_media_playing=false
    active_players=()

    for p in "${players[@]}"; do
        [[ -z "$p" ]] && continue
        status=$(playerctl -p "$p" status 2>/dev/null || true)
        if [[ "$status" == "Playing" ]]; then
            has_media_playing=true
            active_players+=("$p")
        fi
    done

    target_mode="idle"

    if [[ "$has_media_playing" == true ]]; then
        is_video=false
        focused_app=""
        is_any_fullscreen=false

        if [[ -n "${NIRI_SOCKET:-}" ]] && command -v niri &>/dev/null; then
            # Query focused window
            focused_json=$(niri msg -j focused-window 2>/dev/null || true)
            if [[ -n "$focused_json" ]]; then
                focused_app=$(echo "$focused_json" | jq -r '.app_id // empty' 2>/dev/null || true)
            fi

            # Query all windows to check fullscreen
            windows_json=$(niri msg -j windows 2>/dev/null || true)
            if [[ -n "$windows_json" ]]; then
                mapfile -t win_geoms < <(echo "$windows_json" | jq -r '.[] | "\(.app_id):\(.layout.window_size[0])x\(.layout.window_size[1])"' 2>/dev/null || true)
                for w in "${win_geoms[@]}"; do
                    # Screen resolution is 1366x768
                    if [[ "$w" =~ 1366x768 ]]; then
                        is_any_fullscreen=true
                        break
                    fi
                done
            fi
        fi

        for player in "${active_players[@]}"; do
            case "$player" in
                *spotify*|*amberol*|*rhythmbox*|*audacious*|*cmus*|*mpd*|*tidal*|*lollypop*)
                    # Pure audio player: never inhibits screen lock or DPMS
                    continue
                    ;;
                *mpv*|*vlc*|*totem*|*celluloid*|*haruna*|*kodi*)
                    # Video player: video if focused or fullscreen
                    if [[ "$is_any_fullscreen" == true ]] || [[ "$focused_app" =~ (mpv|vlc|totem|celluloid|haruna|kodi) ]]; then
                        is_video=true
                        break
                    fi
                    ;;
                *brave*|*chromium*|*chrome*|*firefox*)
                    # Browser: video if focused or fullscreen
                    if [[ "$is_any_fullscreen" == true ]] || [[ "$focused_app" =~ (brave|chromium|chrome|firefox) ]]; then
                        is_video=true
                        break
                    fi
                    ;;
                *)
                    # Other players: if focused, treat as active video
                    if [[ -n "$focused_app" && "$player" =~ $focused_app ]]; then
                        is_video=true
                        break
                    fi
                    ;;
            esac
        done

        if [[ "$is_video" == true ]]; then
            target_mode="video"
        else
            target_mode="audio"
        fi
    else
        target_mode="idle"
    fi

    # Apply state transitions only when changed
    if [[ "$target_mode" != "$current_mode" ]]; then
        case "$target_mode" in
            "video")
                systemctl --user stop swayidle-idle.service swayidle-sleep.service 2>/dev/null || true
                echo "[media-idle-guard] State -> VIDEO (no lock, no DPMS, no sleep)"
                ;;
            "audio")
                systemctl --user start swayidle-idle.service 2>/dev/null || true
                systemctl --user stop swayidle-sleep.service 2>/dev/null || true
                echo "[media-idle-guard] State -> AUDIO (lock/DPMS active, no sleep)"
                ;;
            "idle")
                systemctl --user start swayidle-idle.service swayidle-sleep.service 2>/dev/null || true
                echo "[media-idle-guard] State -> IDLE (lock 5m, DPMS 6m, suspend 15m)"
                ;;
        esac
        current_mode="$target_mode"
    fi

    sleep 4
done
