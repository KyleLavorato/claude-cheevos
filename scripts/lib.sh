#!/usr/bin/env bash
# lib.sh - Shared library for Claude Code Achievement System
# Source this file in hook scripts: source "$(dirname "$0")/../scripts/lib.sh"

# Allow override of ACHIEVEMENTS_DIR for testing
ACHIEVEMENTS_DIR="${ACHIEVEMENTS_DIR:-$HOME/.claude/achievements}"
STATE_FILE="$ACHIEVEMENTS_DIR/state.json"
NOTIFICATIONS_FILE="$ACHIEVEMENTS_DIR/notifications.json"
LOCK_FILE="$ACHIEVEMENTS_DIR/state.lock"
SCRIPTS_DIR="$ACHIEVEMENTS_DIR/scripts"
CHEEVOS="$ACHIEVEMENTS_DIR/cheevos"

# HMAC secret — injected by install.sh at install time.
# This value is used to sign hook payloads so the binary can verify
# they originate from a legitimate hook call (not a direct binary invocation).
_CHEEVOS_HMAC_SECRET=""

# cheevos_ts: emit a nanosecond-precision Unix timestamp.
# Falls back to python3 on macOS where date +%N is unsupported.
cheevos_ts() {
    if [[ "$(uname -s)" == "Darwin" ]]; then
        python3 -c "import time; print(int(time.time()*1e9))" 2>/dev/null || \
            printf '%s000000000' "$(date +%s)"
    else
        date +%s%N 2>/dev/null || printf '%s000000000' "$(date +%s)"
    fi
}

# cheevos_sign: compute HMAC-SHA256 of the hook payload.
# Arguments: counter_updates counter_sets new_model session_id ts
cheevos_sign() {
    local counter_updates="${1:-}"
    local counter_sets="${2:-}"
    local new_model="${3:-}"
    local session_id="${4:-}"
    local ts="${5:-}"
    local sep
    sep=$'\x00'
    local payload="${counter_updates}${sep}${counter_sets}${sep}${new_model}${sep}${session_id}${sep}${ts}"
    printf '%s' "$payload" | openssl dgst -sha256 -hmac "$_CHEEVOS_HMAC_SECRET" -binary 2>/dev/null \
        | base64 | tr -d '\n'
}
