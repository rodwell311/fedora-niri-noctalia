#!/usr/bin/env bash
# ==============================================================================
# Battery Alert Script for Wayland / Noctalia Notification System
# Triggers notification at <= 20% (low) and >= 90% (charged)
# ==============================================================================

BAT_PATH=$(find /sys/class/power_supply/ -name "BAT*" | head -n 1)
[ -z "$BAT_PATH" ] && exit 0

CAPACITY=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo 0)
STATUS=$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unknown")

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/battery-alert"
mkdir -p "$STATE_DIR"

LOW_NOTIFIED="$STATE_DIR/low_notified"
HIGH_NOTIFIED="$STATE_DIR/high_notified"

# Low Battery Alert (<= 20% and Discharging)
if [ "$CAPACITY" -le 20 ] && [ "$STATUS" = "Discharging" ]; then
    if [ ! -f "$LOW_NOTIFIED" ]; then
        notify-send -u critical -i battery-caution \
            "Baterai Lemah (${CAPACITY}%)" \
            "Baterai sudah mencapai ${CAPACITY}%. Segera sambungkan charger."
        touch "$LOW_NOTIFIED"
    fi
else
    # Reset flag when charged above 25% or plugged in
    if [ "$CAPACITY" -gt 25 ] || [ "$STATUS" != "Discharging" ]; then
        rm -f "$LOW_NOTIFIED"
    fi
fi

# High / Full Battery Alert (>= 90% and Charging)
if [ "$CAPACITY" -ge 90 ] && [ "$STATUS" = "Charging" ]; then
    if [ ! -f "$HIGH_NOTIFIED" ]; then
        notify-send -u normal -i battery-full-charging \
            "Baterai Cukup (${CAPACITY}%)" \
            "Baterai sudah mencapai ${CAPACITY}%. Cabut charger untuk menjaga battery health."
        touch "$HIGH_NOTIFIED"
    fi
else
    # Reset flag when discharging below 85%
    if [ "$CAPACITY" -lt 85 ] || [ "$STATUS" = "Discharging" ]; then
        rm -f "$HIGH_NOTIFIED"
    fi
fi
