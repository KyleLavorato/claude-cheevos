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

INPUT=$(cat)
SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"')

# Track session resumes separately, then exit
if [[ "$SOURCE" == "resume" ]]; then
    init_state
    export _STATE_FILE="$STATE_FILE"
    export _DEFS_FILE="$DEFS_FILE"
    export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
    export _COUNTER_UPDATES='{"session_resumes": 1}'
    with_lock bash "$SCRIPTS_DIR/state-update.sh"
    exit 0
fi

# Skip compact, clear, and any other non-startup events
if [[ "$SOURCE" != "startup" ]]; then
    exit 0
fi

init_state

# ─── Streak tracking ──────────────────────────────────────────────────────────
# Compute days since Unix epoch for today (integer, same across timezones)
TODAY_EPOCH=$(( $(date +%s) / 86400 ))

LAST_EPOCH=$(jq -r '.counters.last_session_epoch // 0' "$STATE_FILE" 2>/dev/null || echo 0)
CURRENT_STREAK=$(jq -r '.counters.streak_days // 0' "$STATE_FILE" 2>/dev/null || echo 0)
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
CLAUDE_COUNT=$(pgrep -f "[/]claude$" 2>/dev/null | wc -l | tr -d '[:space:]') || CLAUDE_COUNT=1
if (( CLAUDE_COUNT >= 5 )); then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"concurrent_sessions_5": 1}')
fi

# Time-based achievements (local time)
HOUR=$(printf '%d' "$(date +%H)")   # 0–23
DOW=$(printf '%d' "$(date +%u)")    # 1=Mon … 5=Fri … 7=Sun

# Midnight session: midnight to 4:59am
if (( HOUR < 5 )); then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"midnight_sessions": 1}')
fi

# Friday after 4pm
if (( DOW == 5 && HOUR >= 16 )); then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"friday_sessions": 1}')
fi

# Dangerous launch detection — increments dangerous_launches and maintains a
# separate consecutive-day streak (dangerous_streak) that resets if the flag
# is absent, enabling the "Do as I Say Not as I Do" achievement.
CURRENT_DANGER_STREAK=$(jq -r '.counters.dangerous_streak // 0' "$STATE_FILE" 2>/dev/null || echo 0)
if ps -p "$PPID" -o args= 2>/dev/null | grep -q "\-\-dangerously-skip-permissions"; then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"dangerous_launches": 1}')
    NEW_DANGER_STREAK=$(( CURRENT_DANGER_STREAK + 1 ))
else
    NEW_DANGER_STREAK=0
fi

export _COUNTER_SETS="{\"streak_days\": ${NEW_STREAK}, \"last_session_epoch\": ${TODAY_EPOCH}, \"dangerous_streak\": ${NEW_DANGER_STREAK}}"

# Style Points — user had a custom statusLine configured before cheevos
# install.sh saves the original command to .original-statusline; non-empty = custom status
if [[ -s "$ACHIEVEMENTS_DIR/.original-statusline" ]]; then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"custom_statusline_set": 1}')
fi

export _COUNTER_UPDATES="$UPDATES"

export _STATE_FILE="$STATE_FILE"
export _DEFS_FILE="$DEFS_FILE"
export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"

with_lock bash "$SCRIPTS_DIR/state-update.sh"

# ─── Auto-update check (once per day, runs in background) ────────────────────
# Check for new achievement definitions from the public GitHub repo
bash "$SCRIPTS_DIR/check-updates.sh" &

exit 0
