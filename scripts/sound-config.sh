#!/usr/bin/env bash
# sound-config.sh - Configure achievement sound settings
#
# Usage:
#   bash sound-config.sh enable              # Enable sounds
#   bash sound-config.sh disable             # Disable sounds
#   bash sound-config.sh volume <0-100>      # Set volume
#   bash sound-config.sh pack <name>         # Set sound pack
#   bash sound-config.sh quiet-hours <start> <end>  # e.g. 22:00 07:00
#   bash sound-config.sh show                # Show current settings

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACHIEVEMENTS_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$ACHIEVEMENTS_DIR/sound-config.json"

# Initialize default config if not exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    cat > "$CONFIG_FILE" << 'EOF'
{
  "enabled": true,
  "pack": "default",
  "volume": 75,
  "quiet_hours": {
    "start": "",
    "end": ""
  }
}
EOF
fi

ACTION="${1:-show}"

case "$ACTION" in
    enable)
        jq '.enabled = true' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✓ Sounds enabled"
        ;;

    disable)
        jq '.enabled = false' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✓ Sounds disabled"
        ;;

    volume)
        VOL="${2:-75}"
        if ! [[ "$VOL" =~ ^[0-9]+$ ]] || (( VOL < 0 || VOL > 100 )); then
            echo "ERROR: Volume must be between 0 and 100"
            exit 1
        fi
        jq --argjson v "$VOL" '.volume = $v' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✓ Volume set to $VOL%"
        ;;

    pack)
        PACK="${2:-default}"
        SOUNDS_DIR="$ACHIEVEMENTS_DIR/data/sounds"

        if [[ ! -d "$SOUNDS_DIR/$PACK" ]]; then
            echo "ERROR: Sound pack '$PACK' not found in $SOUNDS_DIR/"
            echo "Available packs:"
            find "$SOUNDS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null || echo "  (none)"
            exit 1
        fi

        jq --arg p "$PACK" '.pack = $p' "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✓ Sound pack set to '$PACK'"
        ;;

    quiet-hours)
        START="${2:-}"
        END="${3:-}"

        if [[ -z "$START" || -z "$END" ]]; then
            echo "Usage: $0 quiet-hours <start-time> <end-time>"
            echo "Example: $0 quiet-hours 22:00 07:00"
            exit 1
        fi

        # Basic time format validation (HH:MM)
        if ! [[ "$START" =~ ^[0-9]{2}:[0-9]{2}$ ]] || ! [[ "$END" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
            echo "ERROR: Times must be in HH:MM format (e.g., 22:00)"
            exit 1
        fi

        jq --arg s "$START" --arg e "$END" '.quiet_hours.start = $s | .quiet_hours.end = $e' \
            "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
        echo "✓ Quiet hours set: $START - $END"
        ;;

    show)
        if [[ ! -f "$CONFIG_FILE" ]]; then
            echo "Sound configuration not found (using defaults)"
            exit 0
        fi

        ENABLED=$(jq -r '.enabled' "$CONFIG_FILE")
        PACK=$(jq -r '.pack' "$CONFIG_FILE")
        VOL=$(jq -r '.volume' "$CONFIG_FILE")
        Q_START=$(jq -r '.quiet_hours.start' "$CONFIG_FILE")
        Q_END=$(jq -r '.quiet_hours.end' "$CONFIG_FILE")

        echo "Achievement Sound Settings"
        echo "=========================="
        echo "  Status:       $(if [[ "$ENABLED" == "true" ]]; then echo "✓ Enabled"; else echo "✗ Disabled"; fi)"
        echo "  Sound Pack:   $PACK"
        echo "  Volume:       ${VOL}%"

        if [[ -n "$Q_START" && -n "$Q_END" ]]; then
            echo "  Quiet Hours:  $Q_START - $Q_END"
        else
            echo "  Quiet Hours:  None"
        fi
        ;;

    *)
        echo "Usage: $0 <action> [args]"
        echo ""
        echo "Actions:"
        echo "  enable                    Enable achievement sounds"
        echo "  disable                   Disable achievement sounds"
        echo "  volume <0-100>            Set volume percentage"
        echo "  pack <name>               Switch sound pack"
        echo "  quiet-hours <start> <end> Set quiet hours (HH:MM format)"
        echo "  show                      Show current settings"
        echo ""
        echo "Examples:"
        echo "  $0 enable"
        echo "  $0 volume 50"
        echo "  $0 pack default"
        echo "  $0 quiet-hours 22:00 07:00"
        exit 1
        ;;
esac
