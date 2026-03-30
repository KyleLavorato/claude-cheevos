#!/usr/bin/env bash
# auto-update.sh - Auto-update definitions.json from the public GitHub repo
#
# Usage:
#   bash auto-update.sh [--force] [--quiet]
#
# Options:
#   --force   Skip timestamp check, always fetch latest definitions
#   --quiet   Suppress all output except errors
#
# Exit codes:
#   0 - Success (definitions updated or already current)
#   1 - Error (network failure, invalid JSON, etc.)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

GITHUB_RAW_URL="https://raw.githubusercontent.com/KyleLavorato/claude-cheevos/main/data/definitions.json"
LAST_CHECK_FILE="$ACHIEVEMENTS_DIR/.last-update-check"
CHECK_COOLDOWN_SECONDS=3600  # 1 hour minimum between automatic checks

FORCE_UPDATE=0
QUIET_MODE=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --force)
            FORCE_UPDATE=1
            shift
            ;;
        --quiet)
            QUIET_MODE=1
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            echo "Usage: auto-update.sh [--force] [--quiet]" >&2
            exit 1
            ;;
    esac
done

# Check if we've checked recently (unless --force)
if [[ $FORCE_UPDATE -eq 0 ]] && [[ -f "$LAST_CHECK_FILE" ]]; then
    LAST_CHECK=$(cat "$LAST_CHECK_FILE" 2>/dev/null || echo 0)
    NOW=$(date +%s)
    ELAPSED=$(( NOW - LAST_CHECK ))

    if (( ELAPSED < CHECK_COOLDOWN_SECONDS )); then
        # Too soon since last check
        exit 0
    fi
fi

# Update last check timestamp
date +%s > "$LAST_CHECK_FILE"

# Fetch remote definitions.json
TEMP_REMOTE=$(mktemp)
trap 'rm -f "$TEMP_REMOTE"' EXIT

if ! curl -fsSL --max-time 10 "$GITHUB_RAW_URL" -o "$TEMP_REMOTE" 2>/dev/null; then
    # Network error or timeout - fail silently (don't break user's session)
    exit 0
fi

# Validate remote JSON
if ! jq empty "$TEMP_REMOTE" 2>/dev/null; then
    echo "Warning: Remote definitions.json is not valid JSON" >&2
    exit 1
fi

# Ensure local definitions.json exists
if [[ ! -f "$DEFS_FILE" ]]; then
    echo "Error: Local definitions.json not found at $DEFS_FILE" >&2
    exit 1
fi

# Compare local and remote
LOCAL_IDS=$(jq -r '.achievements[].id' "$DEFS_FILE" | sort)
REMOTE_IDS=$(jq -r '.achievements[].id' "$TEMP_REMOTE" | sort)

# Find new achievement IDs (in remote but not local)
NEW_IDS=$(comm -13 <(echo "$LOCAL_IDS") <(echo "$REMOTE_IDS"))
NEW_COUNT=$(echo "$NEW_IDS" | grep -c . || echo 0)

# Find updated achievement IDs (IDs that exist in both but have different content)
COMMON_IDS=$(comm -12 <(echo "$LOCAL_IDS") <(echo "$REMOTE_IDS"))
UPDATED_IDS=""
UPDATED_COUNT=0

while IFS= read -r aid; do
    [[ -z "$aid" ]] && continue

    LOCAL_ACHV=$(jq --arg id "$aid" '.achievements[] | select(.id == $id)' "$DEFS_FILE")
    REMOTE_ACHV=$(jq --arg id "$aid" '.achievements[] | select(.id == $id)' "$TEMP_REMOTE")

    # Compare JSON objects (normalize to remove whitespace differences)
    LOCAL_NORM=$(echo "$LOCAL_ACHV" | jq -c -S .)
    REMOTE_NORM=$(echo "$REMOTE_ACHV" | jq -c -S .)

    if [[ "$LOCAL_NORM" != "$REMOTE_NORM" ]]; then
        if [[ -z "$UPDATED_IDS" ]]; then
            UPDATED_IDS="$aid"
        else
            UPDATED_IDS="$UPDATED_IDS"$'\n'"$aid"
        fi
        UPDATED_COUNT=$(( UPDATED_COUNT + 1 ))
    fi
done <<< "$COMMON_IDS"

# If nothing changed, exit early
if [[ $NEW_COUNT -eq 0 ]] && [[ $UPDATED_COUNT -eq 0 ]]; then
    exit 0
fi

# Merge changes into local definitions.json
# Strategy: Start with remote achievements, preserve local schema_version
MERGED=$(jq -s '
    {
        schema_version: (.[0].schema_version // 1),
        achievements: .[1].achievements
    }
' "$DEFS_FILE" "$TEMP_REMOTE")

# Write merged result atomically using temp file + rename
TEMP_MERGED=$(mktemp)
echo "$MERGED" > "$TEMP_MERGED"

# Validate merged JSON before overwriting
if ! jq empty "$TEMP_MERGED" 2>/dev/null; then
    echo "Error: Merged definitions.json is not valid JSON" >&2
    rm -f "$TEMP_MERGED"
    exit 1
fi

# Atomic replace
mv -f "$TEMP_MERGED" "$DEFS_FILE"

# Report changes (unless --quiet)
if [[ $QUIET_MODE -eq 0 ]] && { [[ $NEW_COUNT -gt 0 ]] || [[ $UPDATED_COUNT -gt 0 ]]; }; then
    echo "🔄 Achievement definitions updated:"

    if [[ $NEW_COUNT -gt 0 ]]; then
        echo "   • $NEW_COUNT new achievement(s) added"

        # Show names of new achievements
        while IFS= read -r aid; do
            [[ -z "$aid" ]] && continue
            NAME=$(jq -r --arg id "$aid" '.achievements[] | select(.id == $id) | .name' "$DEFS_FILE")
            POINTS=$(jq -r --arg id "$aid" '.achievements[] | select(.id == $id) | .points' "$DEFS_FILE")
            echo "     - $NAME (+${POINTS} pts)"
        done <<< "$NEW_IDS"
    fi

    if [[ $UPDATED_COUNT -gt 0 ]]; then
        echo "   • $UPDATED_COUNT achievement(s) updated"
    fi
fi

exit 0
