#!/usr/bin/env bash
# ==============================================================================
# Reset stale WirePlumber microphone state (Acer Aspire A515-45 / Realtek ALC256)
# Clears corrupted route volume/mute states while preserving WebRTC pulse quirks.
# ==============================================================================
set -Eeuo pipefail

state_dir="$HOME/.local/state/wireplumber"
stamp="$(date +%Y%m%d-%H%M%S)"
backup_dir="$state_dir/backups/mic-reset-$stamp"

need() {
    command -v "$1" >/dev/null 2>&1 || {
        printf 'Missing required command: %s\n' "$1" >&2
        exit 127
    }
}

for command in systemctl wpctl python3; do
    need "$command"
done

if [[ "${1:-}" == "--check" ]]; then
    printf 'Ready. Target state: %s\n' "$state_dir"
    printf 'Current source: '
    wpctl get-volume @DEFAULT_AUDIO_SOURCE@ || true
    exit 0
fi

mkdir -p "$state_dir" "$backup_dir"

# Stop policy manager before editing its persistent state.
systemctl --user stop wireplumber.service

for file in default-nodes default-routes; do
    if [[ -f "$state_dir/$file" ]]; then
        cp -a -- "$state_dir/$file" "$backup_dir/$file"
    fi
done

python3 - "$state_dir/default-nodes" "$state_dir/default-routes" <<'PY'
from pathlib import Path
import sys

nodes = Path(sys.argv[1])
routes = Path(sys.argv[2])

if nodes.exists():
    nodes.write_text(
        "".join(
            line for line in nodes.read_text().splitlines(keepends=True)
            if not line.startswith("default.configured.audio.source")
        )
    )

if routes.exists():
    blocked = (
        "usb-FIIO_SNOWSKY_TINY_B_",
        "input:analog-input-headset-mic=",
        "input:analog-input-internal-mic=",
    )
    routes.write_text(
        "".join(
            line for line in routes.read_text().splitlines(keepends=True)
            if not any(token in line for token in blocked)
        )
    )
PY

systemctl --user start wireplumber.service

source_id=""
for _ in $(seq 1 15); do
    source_id="$({ wpctl status || true; } | python3 -c '
import re
import sys
text = sys.stdin.read()
section = re.search(r"Sources:\n(.*?)(?:\n.*Filters:)", text, re.S)
if section:
    lines = section.group(1).splitlines()
    for line in lines:
        if "Ryzen HD Audio Controller Analog Stereo" in line:
            match = re.search(r"(\d+)\.", line)
            if match:
                print(match.group(1))
                sys.exit(0)
    for line in lines:
        if "Analog Stereo" in line:
            match = re.search(r"(\d+)\.", line)
            if match:
                print(match.group(1))
                sys.exit(0)
')"
    [[ -n "$source_id" ]] && break
    sleep 1
done

[[ -n "$source_id" ]] || {
    printf 'Laptop microphone source did not appear after WirePlumber restart.\n' >&2
    printf 'Backup retained at: %s\n' "$backup_dir" >&2
    exit 1
}

wpctl set-default "$source_id"
wpctl set-volume "$source_id" 0.50
wpctl set-mute "$source_id" 0

result="$(wpctl get-volume "$source_id")"
printf 'Backup: %s\n' "$backup_dir"
printf 'Source %s: %s\n' "$source_id" "$result"

[[ "$result" != *MUTED* ]] || {
    printf 'Source is still muted; state was reset but mute did not clear.\n' >&2
    exit 1
}

printf 'Done. Reboot check: wpctl get-volume @DEFAULT_AUDIO_SOURCE@\n'
