#!/usr/bin/env bash
# uninstall.sh - Remove Claude Code Achievement System (binary edition)
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
        jq --arg cmd "$ORIG_CMD" '.statusLine.command = $cmd' "$SETTINGS" > "$TEMP"
        mv "$TEMP" "$SETTINGS"
        echo "✓ Restored original statusLine: $ORIG_CMD"
    else
        jq 'del(.statusLine)' "$SETTINGS" > "$TEMP"
        mv "$TEMP" "$SETTINGS"
        echo "✓ Removed statusLine (none existed before install)"
    fi
else
    echo "  (No .original-statusline found - statusLine not modified)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 2: Remove achievement hooks from settings.json
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
        .hooks |= with_entries(select(.value | length > 0))
    else . end
' "$SETTINGS" > "$TEMP" && mv "$TEMP" "$SETTINGS"

echo "✓ Removed achievement hooks from settings.json"

# ─────────────────────────────────────────────────────────────────────────────
# Step 2.5: Remove slash commands
# ─────────────────────────────────────────────────────────────────────────────

COMMAND_FILE="$HOME/.claude/commands/achievements.md"
if [[ -f "$COMMAND_FILE" ]]; then
    rm -f "$COMMAND_FILE"
    echo "✓ Removed /achievements slash command"
fi

UNINSTALL_COMMAND_FILE="$HOME/.claude/commands/uninstall-achievements.md"
if [[ -f "$UNINSTALL_COMMAND_FILE" ]]; then
    rm -f "$UNINSTALL_COMMAND_FILE"
    echo "✓ Removed /uninstall-achievements slash command"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 3: Remove from leaderboard (if enabled)
# ─────────────────────────────────────────────────────────────────────────────

LEADERBOARD_CONF="$ACHIEVEMENTS_DIR/leaderboard.conf"
if [[ -f "$LEADERBOARD_CONF" ]]; then
    LEADERBOARD_ENABLED=$(grep -m1 '^LEADERBOARD_ENABLED=' "$LEADERBOARD_CONF" | cut -d= -f2-)
    if [[ "$LEADERBOARD_ENABLED" == "true" ]]; then
        USER_ID=$(grep -m1 '^USER_ID='  "$LEADERBOARD_CONF" | cut -d= -f2-)
        TOKEN=$(grep -m1   '^TOKEN='    "$LEADERBOARD_CONF" | cut -d= -f2-)
        API_URL=$(grep -m1 '^API_URL='  "$LEADERBOARD_CONF" | cut -d= -f2-)

        if [[ -n "$USER_ID" && -n "$TOKEN" && -n "$API_URL" ]]; then
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
                --connect-timeout 5 --max-time 10 \
                -X DELETE \
                -H "Authorization: Bearer ${TOKEN}" \
                "${API_URL}/users/${USER_ID}" 2>/dev/null || true)
            if [[ "$HTTP_CODE" == "200" ]]; then
                echo "✓ Removed from leaderboard (user: $USER_ID)"
            else
                echo "  (Leaderboard removal skipped — HTTP $HTTP_CODE)"
            fi
        fi
    fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 4: Optionally delete achievement data (including binary and key)
# ─────────────────────────────────────────────────────────────────────────────

echo ""
if [[ -d "$ACHIEVEMENTS_DIR" ]]; then
    # Show score if state is readable (try jq on the raw file as a heuristic first;
    # if encrypted it'll show 0/0 which is fine)
    SCORE=0
    UNLOCKED=0
    if [[ -x "$ACHIEVEMENTS_DIR/cheevos" ]]; then
        SCORE=$("$ACHIEVEMENTS_DIR/cheevos" show --unlocked 2>/dev/null | grep -o '[0-9]* pts' | head -1 | grep -o '[0-9]*' || echo 0)
    fi
    echo "Achievement data at: $ACHIEVEMENTS_DIR"
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
