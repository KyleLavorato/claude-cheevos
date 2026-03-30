#!/usr/bin/env bash
# play-sound.sh - Play achievement unlock sounds
#
# Plays appropriate sound based on achievement tier.
# Uses system beeps or audio files depending on platform and configuration.
#
# Usage: bash play-sound.sh <tier> [achievement-name]
#   tier: beginner, intermediate, experienced, master, impossible, secret, rank

set -euo pipefail

TIER="${1:-beginner}"
ACHIEVEMENT_NAME="${2:-Achievement}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ACHIEVEMENTS_DIR="$(dirname "$SCRIPT_DIR")"
SOUNDS_DIR="$ACHIEVEMENTS_DIR/data/sounds"

# Check if sounds are enabled
SOUND_ENABLED=true
if [[ -f "$ACHIEVEMENTS_DIR/sound-config.json" ]]; then
    SOUND_ENABLED=$(jq -r '.enabled // true' "$ACHIEVEMENTS_DIR/sound-config.json" 2>/dev/null || echo true)
fi

if [[ "$SOUND_ENABLED" != "true" ]]; then
    exit 0  # Sounds disabled, exit silently
fi

# Check quiet hours (optional)
if [[ -f "$ACHIEVEMENTS_DIR/sound-config.json" ]]; then
    QUIET_START=$(jq -r '.quiet_hours.start // ""' "$ACHIEVEMENTS_DIR/sound-config.json" 2>/dev/null || echo "")
    QUIET_END=$(jq -r '.quiet_hours.end // ""' "$ACHIEVEMENTS_DIR/sound-config.json" 2>/dev/null || echo "")

    if [[ -n "$QUIET_START" && -n "$QUIET_END" ]]; then
        CURRENT_HOUR=$(date +%H)
        QUIET_START_HOUR=${QUIET_START%%:*}
        QUIET_END_HOUR=${QUIET_END%%:*}

        # Simple range check (doesn't handle wraparound midnight properly, but good enough)
        if (( CURRENT_HOUR >= QUIET_START_HOUR || CURRENT_HOUR < QUIET_END_HOUR )); then
            exit 0  # In quiet hours, exit silently
        fi
    fi
fi

# Get volume setting (0-100, default 75)
VOLUME=75
if [[ -f "$ACHIEVEMENTS_DIR/sound-config.json" ]]; then
    VOLUME=$(jq -r '.volume // 75' "$ACHIEVEMENTS_DIR/sound-config.json" 2>/dev/null || echo 75)
fi

# Platform detection
PLATFORM="$(uname -s)"

# ─── Play sound based on tier ──────────────────────────────────────────────────

play_audio_file() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        return 1
    fi

    case "$PLATFORM" in
        Darwin)
            # macOS: use afplay with volume control
            # Note: afplay doesn't have direct volume control, so we use system volume
            afplay "$file" &
            ;;
        Linux)
            # Linux: try multiple players
            if command -v paplay >/dev/null 2>&1; then
                paplay --volume=$((VOLUME * 655)) "$file" &  # PulseAudio (0-65535 scale)
            elif command -v aplay >/dev/null 2>&1; then
                aplay -q "$file" &  # ALSA
            elif command -v ffplay >/dev/null 2>&1; then
                ffplay -nodisp -autoexit -volume "$VOLUME" "$file" >/dev/null 2>&1 &
            else
                return 1
            fi
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

# Determine sound file based on tier
SOUND_PACK="default"
if [[ -f "$ACHIEVEMENTS_DIR/sound-config.json" ]]; then
    SOUND_PACK=$(jq -r '.pack // "default"' "$ACHIEVEMENTS_DIR/sound-config.json" 2>/dev/null || echo "default")
fi

SOUND_FILE="$SOUNDS_DIR/$SOUND_PACK/${TIER}.wav"

# Try to play audio file first
if play_audio_file "$SOUND_FILE"; then
    exit 0
fi

# Fallback: System beeps with different patterns per tier
case "$TIER" in
    beginner)
        # Single pleasant beep (Pavlovian ding!)
        case "$PLATFORM" in
            Darwin)
                afplay /System/Library/Sounds/Tink.aiff 2>/dev/null &
                ;;
            *)
                printf '\a'  # Terminal bell
                ;;
        esac
        ;;

    intermediate)
        # Double beep
        case "$PLATFORM" in
            Darwin)
                afplay /System/Library/Sounds/Pop.aiff 2>/dev/null &
                ;;
            *)
                printf '\a'; sleep 0.1; printf '\a'
                ;;
        esac
        ;;

    experienced)
        # Triple ascending beep
        case "$PLATFORM" in
            Darwin)
                afplay /System/Library/Sounds/Blow.aiff 2>/dev/null &
                ;;
            *)
                printf '\a'; sleep 0.1; printf '\a'; sleep 0.1; printf '\a'
                ;;
        esac
        ;;

    master)
        # Triumphant sound
        case "$PLATFORM" in
            Darwin)
                afplay /System/Library/Sounds/Glass.aiff 2>/dev/null &
                ;;
            *)
                printf '\a'; sleep 0.05; printf '\a'; sleep 0.05; printf '\a'; sleep 0.2; printf '\a'
                ;;
        esac
        ;;

    impossible|rank)
        # Epic fanfare
        case "$PLATFORM" in
            Darwin)
                afplay /System/Library/Sounds/Funk.aiff 2>/dev/null &
                ;;
            *)
                for i in {1..5}; do
                    printf '\a'
                    sleep 0.08
                done
                ;;
        esac
        ;;

    secret)
        # Mystery sound
        case "$PLATFORM" in
            Darwin)
                afplay /System/Library/Sounds/Submarine.aiff 2>/dev/null &
                ;;
            *)
                printf '\a'; sleep 0.3; printf '\a'
                ;;
        esac
        ;;

    *)
        # Default beep
        printf '\a'
        ;;
esac
