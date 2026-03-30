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

# ─── Log dir must exist before any log call ───────────────────────────────────
mkdir -p "$(dirname "$LEADERBOARD_LOG_FILE")"

# ─── Logging helper ───────────────────────────────────────────────────────────
log() {
    local level="$1"; shift
    local ts
    ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")
    printf '[%s] [%s] %s\n' "$ts" "$level" "$*" >> "$LEADERBOARD_LOG_FILE"
}

log "INFO" "leaderboard-sync started"

# ─── Config check ─────────────────────────────────────────────────────────────
if [[ ! -f "$LEADERBOARD_CONF" ]]; then
    log "SKIP" "leaderboard.conf not found at $LEADERBOARD_CONF"
    exit 0
fi

LEADERBOARD_ENABLED=$(grep -m1 '^LEADERBOARD_ENABLED=' "$LEADERBOARD_CONF" | cut -d= -f2-)
if [[ "$LEADERBOARD_ENABLED" != "true" ]]; then
    log "SKIP" "LEADERBOARD_ENABLED=$LEADERBOARD_ENABLED (not true)"
    exit 0
fi

# ─── Read config ──────────────────────────────────────────────────────────────
USER_ID=$(grep -m1  '^USER_ID='  "$LEADERBOARD_CONF" | cut -d= -f2-)
USERNAME=$(grep -m1 '^USERNAME=' "$LEADERBOARD_CONF" | cut -d= -f2-)
TOKEN=$(grep -m1    '^TOKEN='    "$LEADERBOARD_CONF" | cut -d= -f2-)
API_URL=$(grep -m1  '^API_URL='  "$LEADERBOARD_CONF" | cut -d= -f2-)

# Abort if any required field is empty
if [[ -z "$TOKEN" ]]; then
    log "SKIP" "TOKEN is empty in leaderboard.conf"
    exit 0
fi
if [[ -z "$API_URL" ]]; then
    log "SKIP" "API_URL is empty in leaderboard.conf"
    exit 0
fi
if [[ -z "$USER_ID" ]]; then
    log "SKIP" "USER_ID is empty in leaderboard.conf"
    exit 0
fi

log "INFO" "config ok: user=$USER_ID username=$USERNAME api=$API_URL"

# ─── Read state ───────────────────────────────────────────────────────────────
if [[ ! -f "$STATE_FILE" ]]; then
    log "SKIP" "state.json not found at $STATE_FILE"
    exit 0
fi

SCORE=$(jq -r '.score // 0' "$STATE_FILE" 2>/dev/null || echo 0)
UNLOCK_COUNT=$(jq -r '.unlocked | length' "$STATE_FILE" 2>/dev/null || echo 0)
LAST_UPDATED=$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "")

log "INFO" "state read: score=$SCORE unlocks=$UNLOCK_COUNT"

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

log "INFO" "payload: $PAYLOAD"
log "INFO" "PUT ${API_URL}/users/${USER_ID}"

# ─── PUT to API ───────────────────────────────────────────────────────────────
# Token is passed in the header but never captured in a variable that gets logged.
HTTP_CODE=0
BODY=""
CURL_ERR=""

CURL_ERR_FILE=$(mktemp /tmp/cheevos-curl-err.XXXXXX)

CURL_OUT=$(curl -s -w "\n__HTTP_CODE__%{http_code}" \
    --connect-timeout 5 \
    --max-time 10 \
    -X PUT \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "${API_URL}/users/${USER_ID}" 2>"$CURL_ERR_FILE" || true)

CURL_ERR=$(cat "$CURL_ERR_FILE" 2>/dev/null || echo "")
rm -f "$CURL_ERR_FILE"

if [[ -n "$CURL_ERR" ]]; then
    log "WARN" "curl stderr: $CURL_ERR"
fi

# Split body and status code (last line is __HTTP_CODE__NNN)
# sed '$d' removes the last line — portable across BSD (macOS) and GNU sed,
# unlike 'head -n -1' which GNU-only and exits non-zero on macOS under set -e.
BODY=$(printf '%s' "$CURL_OUT" | sed '$d')
HTTP_LINE=$(printf '%s' "$CURL_OUT" | tail -n 1)
HTTP_CODE=$(printf '%s' "$HTTP_LINE" | sed 's/__HTTP_CODE__//')

# ─── Log result ───────────────────────────────────────────────────────────────
# Token is intentionally omitted from the log entry.
if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "201" || "$HTTP_CODE" == "204" ]]; then
    log "OK" "PUT /users/${USER_ID} score=$SCORE unlocks=$UNLOCK_COUNT http=$HTTP_CODE body=$BODY"
elif [[ -z "$HTTP_CODE" || "$HTTP_CODE" == "0" ]]; then
    log "ERROR" "PUT /users/${USER_ID} — no response (network failure or timeout) body=$BODY"
else
    log "ERROR" "PUT /users/${USER_ID} score=$SCORE unlocks=$UNLOCK_COUNT http=$HTTP_CODE body=$BODY"
fi
