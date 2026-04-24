#!/usr/bin/env bash
# session-start.sh - SessionStart hook
#
# Fires synchronously when Claude Code starts a new session.
# Only counts genuine new sessions (source == "startup"), not
# resume/clear/compact events which also fire SessionStart.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

# Guard: if the binary is not installed, exit gracefully
[[ -x "$CHEEVOS" ]] || exit 0

INPUT=$(cat)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"')

# Track session resumes separately, then exit
if [[ "$SOURCE" == "resume" ]]; then
    "$CHEEVOS" init
    export _STATE_FILE="$STATE_FILE"
    export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
    export _COUNTER_UPDATES='{"session_resumes": 1}'
    _CHEEVOS_TS=$(cheevos_ts)
    export _CHEEVOS_SIG
    _CHEEVOS_SIG=$(cheevos_sign "$_COUNTER_UPDATES" "" "$_CHEEVOS_TS")
    export _CHEEVOS_TS
    "$CHEEVOS" update
    exit 0
fi

# Skip compact, clear, and any other non-startup events
if [[ "$SOURCE" != "startup" ]]; then
    exit 0
fi

"$CHEEVOS" init

# ─── Streak tracking ──────────────────────────────────────────────────────────
# Compute days since Unix epoch for today (integer, same across timezones)
TODAY_EPOCH=$(( $(date +%s) / 86400 ))

LAST_EPOCH=$("$CHEEVOS" get-counter last_session_epoch 2>/dev/null || echo 0)
CURRENT_STREAK=$("$CHEEVOS" get-counter streak_days 2>/dev/null || echo 0)
DIFF=$(( TODAY_EPOCH - LAST_EPOCH ))

if (( DIFF <= 0 )); then
    # Same day — streak already counted for today
    NEW_STREAK=$CURRENT_STREAK
elif (( DIFF == 1 )); then
    # Consecutive day — extend streak
    NEW_STREAK=$(( CURRENT_STREAK + 1 ))
else
    # Gap — reset streak to 1
    NEW_STREAK=1
fi

# ─── Build counter updates ─────────────────────────────────────────────────────
UPDATES='{"sessions": 1}'

# Concurrent session detection
CLAUDE_COUNT=$(pgrep -x claude 2>/dev/null | wc -l | tr -d '[:space:]') || CLAUDE_COUNT=1
if (( CLAUDE_COUNT >= 5 )); then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"concurrent_sessions_5": 1}')
fi

# Time-based achievements (local time)
HOUR=$(( 10#$(date +%H) ))   # 0–23, force base-10 to avoid octal interpretation
DOW=$(printf '%d' "$(date +%u)")    # 1=Mon … 5=Fri … 7=Sun

# Midnight session: midnight to 4:59am
if (( HOUR < 5 )); then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"midnight_sessions": 1}')
fi

# Friday after 4pm
if (( DOW == 5 && HOUR >= 16 )); then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"friday_sessions": 1}')
fi

# Verbose launch detection
if ps -p "$PPID" -o args= 2>/dev/null | grep -q "\-\-verbose"; then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"claude_verbose": 1}')
fi

# Dangerous launch detection — streak counts consecutive DAYS, not sessions
CURRENT_DANGER_STREAK=$("$CHEEVOS" get-counter dangerous_streak 2>/dev/null || echo 0)
PPID_CMD=$(ps -p "$PPID" -o comm= 2>/dev/null || echo "")
if [[ "$PPID_CMD" == "claude" ]]; then
    if ps -p "$PPID" -o args= 2>/dev/null | grep -q "\-\-dangerously-skip-permissions"; then
        UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"dangerous_launches": 1}')
        if (( DIFF <= 0 )); then
            # Same day — already counted today, keep current streak
            NEW_DANGER_STREAK=$CURRENT_DANGER_STREAK
        elif (( DIFF == 1 )); then
            # Consecutive day — extend streak
            NEW_DANGER_STREAK=$(( CURRENT_DANGER_STREAK + 1 ))
        else
            # Gap of more than one day — restart streak at 1
            NEW_DANGER_STREAK=1
        fi
    else
        NEW_DANGER_STREAK=0
    fi
else
    # Non-CLI session (Claude.app, IDE) — preserve existing streak, don't reset
    NEW_DANGER_STREAK=$CURRENT_DANGER_STREAK
fi

export _COUNTER_SETS="{\"streak_days\": ${NEW_STREAK}, \"last_session_epoch\": ${TODAY_EPOCH}, \"dangerous_streak\": ${NEW_DANGER_STREAK}}"

# Style Points — user has a custom statusLine configured
# Check the saved file (install-time) first, then fall back to reading
# settings.json directly to catch post-install customisation (issue #56).
ORIGINAL_SAVE="$ACHIEVEMENTS_DIR/.original-statusline"
HAS_CUSTOM_STATUSLINE=false
if [[ -s "$ORIGINAL_SAVE" ]]; then
    HAS_CUSTOM_STATUSLINE=true
else
    SETTINGS_FILE="$HOME/.claude/settings.json"
    if [[ -f "$SETTINGS_FILE" ]]; then
        CURRENT_CMD=$(jq -r '.statusLine.command // ""' "$SETTINGS_FILE")
        CHEEVOS_DEFAULT="$ACHIEVEMENTS_DIR/cheevos statusline"
        if [[ -n "$CURRENT_CMD" ]] && [[ "$CURRENT_CMD" != "$CHEEVOS_DEFAULT" ]]; then
            HAS_CUSTOM_STATUSLINE=true
        fi
    fi
fi
if [[ "$HAS_CUSTOM_STATUSLINE" == "true" ]]; then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"custom_statusline_set": 1}')
fi

# Learning/Explanatory output style detection
# Check project-local (highest precedence), user-local, then user-global settings
OUTPUT_STYLE=""
for SETTINGS_CANDIDATE in ".claude/settings.local.json" "$HOME/.claude/settings.local.json" "$HOME/.claude/settings.json"; do
    if [[ -f "$SETTINGS_CANDIDATE" ]]; then
        CANDIDATE_STYLE=$(jq -r '.outputStyle // ""' "$SETTINGS_CANDIDATE")
        if [[ -n "$CANDIDATE_STYLE" ]]; then
            OUTPUT_STYLE="$CANDIDATE_STYLE"
            break
        fi
    fi
done
if printf '%s' "$OUTPUT_STYLE" | grep -qi "learning"; then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"learning_mode_sessions": 1}')
fi
if printf '%s' "$OUTPUT_STYLE" | grep -qi "explanatory"; then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"explanatory_mode_sessions": 1}')
fi

export _COUNTER_UPDATES="$UPDATES"
export _STATE_FILE="$STATE_FILE"
export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"

_CHEEVOS_TS=$(cheevos_ts)
export _CHEEVOS_SIG
_CHEEVOS_SIG=$(cheevos_sign "$_COUNTER_UPDATES" "${_COUNTER_SETS:-}" "$_CHEEVOS_TS")
export _CHEEVOS_TS

"$CHEEVOS" update

# Auto-update check (once per day, runs in background — rate-limited inside the binary)
# Skipped if the user has opted out by placing a .no-auto-update flag file.
if [[ ! -f "$ACHIEVEMENTS_DIR/.no-auto-update" ]]; then
    "$CHEEVOS" check-updates &
fi

exit 0
