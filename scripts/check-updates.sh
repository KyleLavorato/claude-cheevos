#!/usr/bin/env bash
# check-updates.sh - Auto-update achievement definitions from GitHub
#
# Checks the public GitHub repo for new achievement definitions and merges them
# into the local definitions.json. Only runs once per day to avoid API rate limits.
#
# Usage: bash check-updates.sh [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

# ─── Configuration ────────────────────────────────────────────────────────────
GITHUB_REPO="KyleLavorato/claude-cheevos"
GITHUB_BRANCH="main"
DEFINITIONS_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/${GITHUB_BRANCH}/data/definitions.json"
UPDATE_INTERVAL=86400  # 24 hours in seconds

# ─── Parse arguments ──────────────────────────────────────────────────────────
FORCE=false
if [[ "${1:-}" == "--force" ]]; then
    FORCE=true
fi

# ─── Rate limiting check ──────────────────────────────────────────────────────
init_state

LAST_CHECK=$(jq -r '.last_update_check_epoch // 0' "$STATE_FILE" 2>/dev/null || echo 0)
NOW=$(date +%s)
TIME_SINCE_CHECK=$(( NOW - LAST_CHECK ))

if [[ "$FORCE" == "false" ]] && (( TIME_SINCE_CHECK < UPDATE_INTERVAL )); then
    # Too soon since last check - exit silently
    exit 0
fi

# ─── Fetch remote definitions ─────────────────────────────────────────────────
TEMP_REMOTE=$(mktemp /tmp/cheevos-remote-defs.XXXXXX.json)

# Use curl with timeout and fail gracefully if network is unavailable
if ! curl -sSf -m 10 "$DEFINITIONS_URL" -o "$TEMP_REMOTE" 2>/dev/null; then
    # Network error or repo unavailable - fail silently
    rm -f "$TEMP_REMOTE"
    exit 0
fi

# Validate the downloaded JSON
if ! jq empty "$TEMP_REMOTE" 2>/dev/null; then
    # Invalid JSON - fail silently
    rm -f "$TEMP_REMOTE"
    exit 0
fi

# ─── Compare and merge ────────────────────────────────────────────────────────
# Build a list of new achievement IDs (IDs in remote but not in local)
REMOTE_DEFS=$(cat "$TEMP_REMOTE")
LOCAL_DEFS=$(cat "$DEFS_FILE")

NEW_IDS=$(jq -n \
    --argjson remote "$REMOTE_DEFS" \
    --argjson local "$LOCAL_DEFS" \
    '($remote.achievements | map(.id)) - ($local.achievements | map(.id))')

NEW_COUNT=$(printf '%s' "$NEW_IDS" | jq 'length')

if (( NEW_COUNT == 0 )); then
    # No new achievements - update timestamp and exit
    rm -f "$TEMP_REMOTE"

    # Update last check time in state (under lock)
    export _STATE_FILE="$STATE_FILE"
    export _DEFS_FILE="$DEFS_FILE"
    export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
    export _COUNTER_UPDATES='{}'
    export _UPDATE_CHECK_EPOCH="$NOW"

    with_lock bash "$SCRIPT_DIR/state-update.sh"
    exit 0
fi

# ─── Merge new achievements ───────────────────────────────────────────────────
# Extract new achievements from remote and append to local
MERGED=$(jq -n \
    --argjson remote "$REMOTE_DEFS" \
    --argjson local "$LOCAL_DEFS" \
    --argjson new_ids "$NEW_IDS" \
    '
    $local |
    .achievements += [
        $remote.achievements[] |
        select(.id as $id | $new_ids | index($id) != null)
    ]
    ')

# Write merged definitions atomically
TEMP_MERGED=$(mktemp /tmp/cheevos-merged-defs.XXXXXX.json)
printf '%s' "$MERGED" | jq '.' > "$TEMP_MERGED"
mv "$TEMP_MERGED" "$DEFS_FILE"

rm -f "$TEMP_REMOTE"

# ─── Update state and notify ──────────────────────────────────────────────────
export _STATE_FILE="$STATE_FILE"
export _DEFS_FILE="$DEFS_FILE"
export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
export _COUNTER_UPDATES='{}'
export _UPDATE_CHECK_EPOCH="$NOW"

with_lock bash "$SCRIPT_DIR/state-update.sh"

# ─── User notification ────────────────────────────────────────────────────────
# Build achievement list for notification
NEW_NAMES=$(printf '%s' "$MERGED" | jq -r \
    --argjson new_ids "$NEW_IDS" \
    '[.achievements[] | select(.id as $id | $new_ids | index($id) != null) | .name] | join(", ")')

# Desktop notification
if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS notification
    if (( NEW_COUNT == 1 )); then
        osascript -e "display notification \"${NEW_NAMES}\" with title \"🎁 New Achievement Available!\" sound name \"Glass\"" 2>/dev/null || true
    else
        osascript -e "display notification \"${NEW_COUNT} new achievements: ${NEW_NAMES}\" with title \"🎁 New Achievements Available!\" sound name \"Glass\"" 2>/dev/null || true
    fi
elif [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL Windows toast notification
    _ps_tmp=$(mktemp /tmp/cheevos-update-notif.XXXXXX.ps1)
    _title="🎁 ${NEW_COUNT} New Achievement(s) Available!"
    _body="${NEW_NAMES}"
    _title_esc=$(printf '%s' "$_title" | sed "s/'/''/g")
    _body_esc=$(printf '%s' "$_body" | sed "s/'/''/g")

    cat > "$_ps_tmp" << PSEOF
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
\$title = [System.Security.SecurityElement]::Escape('$_title_esc')
\$body  = [System.Security.SecurityElement]::Escape('$_body_esc')
\$xml   = New-Object Windows.Data.Xml.Dom.XmlDocument
\$xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>\$title</text><text>\$body</text></binding></visual></toast>")
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Cheevos').Show([Windows.UI.Notifications.ToastNotification]::new(\$xml))
PSEOF

    _win_ps_tmp=$(wslpath -w "$_ps_tmp")
    powershell.exe -NonInteractive -NoProfile -WindowStyle Hidden -File "$_win_ps_tmp" 2>/dev/null &
    { sleep 5; rm -f "$_ps_tmp"; } &
fi

exit 0
