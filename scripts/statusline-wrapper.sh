#!/usr/bin/env bash
# statusline-wrapper.sh - Achievement score display for Claude Code status bar
#
# Called by Claude Code as the statusLine.command.
# Receives a JSON blob on stdin, calls the user's original statusLine command
# (if one was saved at install time), then appends the achievement score.

ACHIEVEMENTS_DIR="${ACHIEVEMENTS_DIR:-$HOME/.claude/achievements}"
STATE_FILE="$ACHIEVEMENTS_DIR/state.json"
ORIGINAL_SAVE="$ACHIEVEMENTS_DIR/.original-statusline"

# Buffer stdin - may need to pass to two consumers
INPUT=$(cat)

# --- Read achievement state (no lock: acceptable stale read for display) ---
if [[ -f "$STATE_FILE" ]]; then
    SCORE=$(jq -r '.score // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    ACHIEVEMENT_SEGMENT="🏆 ${SCORE} pts"
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
