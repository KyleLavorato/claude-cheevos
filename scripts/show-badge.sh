#!/usr/bin/env bash
# show-badge.sh - Display achievement badge in terminal
#
# Shows SVG preview (if supported) or ASCII art fallback
# Usage: bash show-badge.sh <achievement-id>

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

init_state

ACHIEVEMENT_ID="${1:-}"

if [[ -z "$ACHIEVEMENT_ID" ]]; then
    echo "Usage: $0 <achievement-id>"
    echo "Example: $0 power_user"
    exit 1
fi

# Load achievement details
DEFS=$(cat "$DEFS_FILE")
ACH=$(printf '%s' "$DEFS" | jq --arg id "$ACHIEVEMENT_ID" '.achievements[] | select(.id == $id)')

if [[ -z "$ACH" ]]; then
    echo "ERROR: Achievement '$ACHIEVEMENT_ID' not found"
    exit 1
fi

NAME=$(printf '%s' "$ACH" | jq -r '.name')
DESC=$(printf '%s' "$ACH" | jq -r '.description')
POINTS=$(printf '%s' "$ACH" | jq -r '.points')
TIER=$(printf '%s' "$ACH" | jq -r '.skill_level')
CATEGORY=$(printf '%s' "$ACH" | jq -r '.category')

# Check if unlocked
STATE=$(cat "$STATE_FILE")
IS_UNLOCKED=$(printf '%s' "$STATE" | jq --arg id "$ACHIEVEMENT_ID" '.unlocked | index($id) != null')
UNLOCK_TIME=""

if [[ "$IS_UNLOCKED" == "true" ]]; then
    UNLOCK_TIME=$(printf '%s' "$STATE" | jq -r --arg id "$ACHIEVEMENT_ID" '.unlock_times[$id] // ""')
fi

# Color codes
if [[ -t 1 ]]; then
    BOLD='\033[1m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    CYAN='\033[36m'
    DIM='\033[2m'
    RESET='\033[0m'
else
    BOLD=''; GREEN=''; YELLOW=''; CYAN=''; DIM=''; RESET=''
fi

# Show badge header
echo ""
printf "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

# Display badge
BADGE_TEMPLATES="$(dirname "$SCRIPT_DIR")/data/badge-templates"
SVG_FILE="$BADGE_TEMPLATES/${TIER}.svg"
ASCII_SCRIPT="$BADGE_TEMPLATES/ascii-badges.sh"

# Try to display SVG if imgcat available (iTerm2)
if command -v imgcat >/dev/null 2>&1 && [[ -f "$SVG_FILE" ]]; then
    imgcat "$SVG_FILE" 2>/dev/null || {
        # Fallback to ASCII if imgcat fails
        bash "$ASCII_SCRIPT" "$TIER" 2>/dev/null || echo "    [Badge: $TIER]"
    }
elif [[ -f "$ASCII_SCRIPT" ]]; then
    # ASCII fallback
    bash "$ASCII_SCRIPT" "$TIER" 2>/dev/null || echo "    [Badge: $TIER]"
else
    # Last resort: simple text
    echo "    🏆 [$TIER]"
fi

# Achievement details
echo ""
printf "${BOLD}${YELLOW}%s${RESET}\n" "$NAME"
printf "${DIM}%s${RESET}\n" "$DESC"
echo ""
printf "  Points:   ${YELLOW}%s${RESET}\n" "+$POINTS pts"
printf "  Category: ${CYAN}%s${RESET}\n" "$CATEGORY"
printf "  Tier:     ${CYAN}%s${RESET}\n" "$TIER"

if [[ "$IS_UNLOCKED" == "true" ]]; then
    printf "  Status:   ${GREEN}✅ UNLOCKED${RESET}\n"
    if [[ -n "$UNLOCK_TIME" ]]; then
        UNLOCK_DATE=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$UNLOCK_TIME" "+%B %d, %Y" 2>/dev/null || echo "$UNLOCK_TIME")
        printf "  Unlocked: ${DIM}%s${RESET}\n" "$UNLOCK_DATE"
    fi
else
    printf "  Status:   🔒 Locked\n"

    # Show progress if applicable
    COUNTER=$(printf '%s' "$ACH" | jq -r '.condition.counter // ""')
    THRESHOLD=$(printf '%s' "$ACH" | jq -r '.condition.threshold // ""')

    if [[ -n "$COUNTER" && "$THRESHOLD" != "null" && "$THRESHOLD" != "" ]]; then
        CURRENT=$(printf '%s' "$STATE" | jq -r --arg c "$COUNTER" '.counters[$c] // 0')
        PERCENT=$(awk "BEGIN {printf \"%.0f\", ($CURRENT / $THRESHOLD) * 100}")
        printf "  Progress: ${CYAN}%s/%s${RESET} ${DIM}(%s%%)${RESET}\n" "$CURRENT" "$THRESHOLD" "$PERCENT"
    fi
fi

printf "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
echo ""
