#!/usr/bin/env bash
# statusline-wrapper.sh - Achievement score display for Claude Code status bar
#
# Called by Claude Code as the statusLine.command.
# Receives a JSON blob on stdin, calls the user's original statusLine command
# (if one was saved at install time), then appends the achievement score.
#
# Displays recently unlocked achievement name for 5 minutes after unlock.

ACHIEVEMENTS_DIR="${ACHIEVEMENTS_DIR:-$HOME/.claude/achievements}"
STATE_FILE="$ACHIEVEMENTS_DIR/state.json"
DEFS_FILE="$ACHIEVEMENTS_DIR/definitions.json"
ORIGINAL_SAVE="$ACHIEVEMENTS_DIR/.original-statusline"

# Buffer stdin - may need to pass to two consumers
INPUT=$(cat)

# --- Read achievement state (no lock: acceptable stale read for display) ---
SCORE=0
ACHIEVEMENT_SEGMENT=""

if [[ -f "$STATE_FILE" ]]; then
    SCORE=$(jq -r '.score // 0' "$STATE_FILE" 2>/dev/null || echo 0)

    # Show name of most recently unlocked achievement for 5 minutes
    LAST_UPDATED=$(jq -r '.last_updated // ""' "$STATE_FILE" 2>/dev/null || echo "")

    if [[ -n "$LAST_UPDATED" ]]; then
        # Parse ISO 8601 timestamp to epoch - handles macOS and Linux
        if [[ "$(uname -s)" == "Darwin" ]]; then
            LAST_TS=$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$LAST_UPDATED" "+%s" 2>/dev/null || echo 0)
        else
            LAST_TS=$(date -d "$LAST_UPDATED" "+%s" 2>/dev/null || echo 0)
        fi
        NOW_TS=$(date "+%s")
        AGE=$(( NOW_TS - LAST_TS ))

        if [[ "$AGE" -lt 300 ]]; then
            LAST_ID=$(jq -r '.unlocked | last // ""' "$STATE_FILE" 2>/dev/null || echo "")
            if [[ -n "$LAST_ID" ]] && [[ -f "$DEFS_FILE" ]]; then
                LAST_NAME=$(jq -r \
                    --arg id "$LAST_ID" \
                    '.achievements[] | select(.id == $id) | .name' \
                    "$DEFS_FILE" 2>/dev/null || echo "")
                [[ -n "$LAST_NAME" ]] && ACHIEVEMENT_SEGMENT="🏆 ${SCORE} pts (${LAST_NAME}!)"
            fi
        fi
    fi

    [[ -z "$ACHIEVEMENT_SEGMENT" ]] && ACHIEVEMENT_SEGMENT="🏆 ${SCORE} pts"
else
    ACHIEVEMENT_SEGMENT="🏆 0 pts"
fi

# --- Call original statusLine command if one was saved at install time ---
ORIGINAL_OUTPUT=""
if [[ -f "$ORIGINAL_SAVE" ]]; then
    ORIG_CMD=$(cat "$ORIGINAL_SAVE")
    if [[ -n "$ORIG_CMD" ]]; then
        ORIGINAL_OUTPUT=$(printf '%s' "$INPUT" | eval "$ORIG_CMD" 2>/dev/null || true)
    fi
fi

# --- Output: original content (if any) + achievement segment ---
if [[ -n "$ORIGINAL_OUTPUT" ]]; then
    printf '%s | %s' "$ORIGINAL_OUTPUT" "$ACHIEVEMENT_SEGMENT"
else
    printf '%s' "$ACHIEVEMENT_SEGMENT"
fi
