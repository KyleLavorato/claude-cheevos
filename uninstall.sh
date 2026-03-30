#!/usr/bin/env bash
# uninstall.sh - Remove Claude Code Achievement System
#
# Restores the original statusLine command and removes achievement hooks
# from ~/.claude/settings.json. Optionally deletes achievement data.
#
# Usage: bash uninstall.sh

set -euo pipefail

ACHIEVEMENTS_DIR="$HOME/.claude/achievements"
SETTINGS="$HOME/.claude/settings.json"

echo "Uninstalling Claude Code Achievement System..."
echo ""

if [[ ! -f "$SETTINGS" ]]; then
    echo "ERROR: $SETTINGS not found."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 1: Restore original statusLine
# ─────────────────────────────────────────────────────────────────────────────

ORIGINAL_SAVE="$ACHIEVEMENTS_DIR/.original-statusline"
if [[ -f "$ORIGINAL_SAVE" ]]; then
    ORIG_CMD=$(cat "$ORIGINAL_SAVE")
    TEMP=$(mktemp "$SETTINGS.XXXXXX")

    if [[ -n "$ORIG_CMD" ]]; then
        # Restore original command
        jq --arg cmd "$ORIG_CMD" '.statusLine.command = $cmd' "$SETTINGS" > "$TEMP"
        mv "$TEMP" "$SETTINGS"
        echo "✓ Restored original statusLine: $ORIG_CMD"
    else
        # No original existed - remove the statusLine key
        jq 'del(.statusLine)' "$SETTINGS" > "$TEMP"
        mv "$TEMP" "$SETTINGS"
        echo "✓ Removed statusLine (none existed before install)"
    fi
else
    echo "  (No .original-statusline found - statusLine not modified)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Remove achievement hooks from settings.json
# Removes any hook entry whose command contains "achievements/hooks"
# ─────────────────────────────────────────────────────────────────────────────

TEMP=$(mktemp "$SETTINGS.XXXXXX")
jq '
    if .hooks then
        .hooks |= with_entries(
            .value |= map(
                select(
                    (.hooks // [] | map(.command // "") | any(contains("achievements/hooks"))) | not
                )
            )
        ) |
        # Remove events that now have no hooks
        .hooks |= with_entries(select(.value | length > 0))
    else . end
' "$SETTINGS" > "$TEMP" && mv "$TEMP" "$SETTINGS"

echo "✓ Removed achievement hooks from settings.json"

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Optionally delete achievement data
# ─────────────────────────────────────────────────────────────────────────────

echo ""
if [[ -f "$ACHIEVEMENTS_DIR/state.json" ]]; then
    SCORE=$(jq -r '.score // 0' "$ACHIEVEMENTS_DIR/state.json" 2>/dev/null || echo 0)
    UNLOCKED=$(jq -r '.unlocked | length' "$ACHIEVEMENTS_DIR/state.json" 2>/dev/null || echo 0)
    echo "Achievement data at: $ACHIEVEMENTS_DIR"
    echo "  Score: $SCORE pts | Unlocked: $UNLOCKED achievements"
    echo ""
    read -r -p "Delete all achievement data? Your progress will be lost. [y/N] " REPLY
    if [[ "$REPLY" =~ ^[Yy]$ ]]; then
        rm -rf "$ACHIEVEMENTS_DIR"
        echo "✓ Achievement data deleted"
    else
        echo "✓ Achievement data preserved"
    fi
else
    echo "(No achievement data found)"
fi

echo ""
echo "Uninstall complete. Restart Claude Code for changes to take effect."
