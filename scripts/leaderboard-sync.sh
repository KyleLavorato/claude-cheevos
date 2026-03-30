#!/usr/bin/env bash
# leaderboard-sync.sh — Push current score to the leaderboard API on achievement unlock.
#
# Called by stop.sh in the background (fire-and-forget) after draining the notification
# queue. Silent on error; all results are logged to LEADERBOARD_LOG_FILE.
# The token is NEVER written to the log — only the HTTP status and response body.
#
# Usage: bash leaderboard-sync.sh  (no arguments; reads config from leaderboard.conf)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

# ─── Config check ─────────────────────────────────────────────────────────────
if [[ ! -f "$LEADERBOARD_CONF" ]]; then
    exit 0
fi

LEADERBOARD_ENABLED=$(grep -m1 '^LEADERBOARD_ENABLED=' "$LEADERBOARD_CONF" | cut -d= -f2-)
if [[ "$LEADERBOARD_ENABLED" != "true" ]]; then
    exit 0
fi

# ─── Read config ──────────────────────────────────────────────────────────────
USER_ID=$(grep -m1  '^USER_ID='  "$LEADERBOARD_CONF" | cut -d= -f2-)
USERNAME=$(grep -m1 '^USERNAME=' "$LEADERBOARD_CONF" | cut -d= -f2-)
TOKEN=$(grep -m1    '^TOKEN='    "$LEADERBOARD_CONF" | cut -d= -f2-)
API_URL=$(grep -m1  '^API_URL='  "$LEADERBOARD_CONF" | cut -d= -f2-)

# Abort silently if any required field is empty
if [[ -z "$TOKEN" || -z "$API_URL" || -z "$USER_ID" ]]; then
    exit 0
fi

# ─── Read state ───────────────────────────────────────────────────────────────
if [[ ! -f "$STATE_FILE" ]]; then
    exit 0
fi

SCORE=$(jq -r '.score // 0' "$STATE_FILE" 2>/dev/null || echo 0)
UNLOCK_COUNT=$(jq -r '.unlocked | length' "$STATE_FILE" 2>/dev/null || echo 0)
LAST_UPDATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")

# ─── Ensure log dir ───────────────────────────────────────────────────────────
mkdir -p "$(dirname "$LEADERBOARD_LOG_FILE")"

# ─── Build payload ────────────────────────────────────────────────────────────
PAYLOAD=$(jq -n \
    --arg username     "$USERNAME" \
    --argjson score    "$SCORE" \
    --argjson unlocks  "$UNLOCK_COUNT" \
    --arg last_updated "$LAST_UPDATED" \
    '{
        username:     $username,
        score:        $score,
        unlock_count: $unlocks,
        last_updated: $last_updated
    }')

# ─── PUT to API ───────────────────────────────────────────────────────────────
# Token is passed in the header but never captured in a variable that gets logged.
HTTP_CODE=0
BODY=""

CURL_OUT=$(curl -s -w "\n__HTTP_CODE__%{http_code}" \
    --connect-timeout 5 \
    --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "${API_URL}/users/${USER_ID}" 2>/dev/null || true)

# Split body and status code (last line is __HTTP_CODE__NNN)
BODY=$(printf '%s' "$CURL_OUT" | head -n -1)
HTTP_LINE=$(printf '%s' "$CURL_OUT" | tail -n 1)
HTTP_CODE=$(printf '%s' "$HTTP_LINE" | sed 's/__HTTP_CODE__//')

# ─── Log result ───────────────────────────────────────────────────────────────
# Token is intentionally omitted from the log entry.
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
printf '[%s] PUT /users/%s score=%s unlocks=%s http=%s body=%s\n' \
    "$TIMESTAMP" "$USER_ID" "$SCORE" "$UNLOCK_COUNT" "$HTTP_CODE" "$BODY" \
    >> "$LEADERBOARD_LOG_FILE"
