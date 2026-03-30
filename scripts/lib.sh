#!/usr/bin/env bash
# lib.sh - Shared library for Claude Code Achievement System
# Source this file in hook scripts: source "$(dirname "$0")/../scripts/lib.sh"

# Allow override of ACHIEVEMENTS_DIR for testing
ACHIEVEMENTS_DIR="${ACHIEVEMENTS_DIR:-$HOME/.claude/achievements}"
STATE_FILE="$ACHIEVEMENTS_DIR/state.json"
DEFS_FILE="$ACHIEVEMENTS_DIR/definitions.json"
NOTIFICATIONS_FILE="$ACHIEVEMENTS_DIR/notifications.json"
LOCK_FILE="$ACHIEVEMENTS_DIR/state.lock"
SCRIPTS_DIR="$ACHIEVEMENTS_DIR/scripts"

# Initialize state files if they don't exist yet
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" << 'EOF'
{
    "schema_version": 1,
    "score": 0,
    "counters": {
        "sessions": 0,
        "files_written": 0,
        "bash_calls": 0,
        "files_read": 0,
        "web_searches": 0,
        "glob_grep_calls": 0,
        "github_mcp_calls": 0,
        "jira_mcp_calls": 0,
        "total_mcp_calls": 0
    },
    "unlocked": [],
    "unlock_times": {},
    "models_used": [],
    "last_session_model_check": "",
    "last_updated": ""
}
EOF
    fi

    if [[ ! -f "$NOTIFICATIONS_FILE" ]]; then
        echo "[]" > "$NOTIFICATIONS_FILE"
    fi
}

# Run a command under exclusive lock on LOCK_FILE
# Cross-platform: uses lockf on macOS, flock on Linux
# Usage: with_lock COMMAND [ARGS...]
with_lock() {
    touch "$LOCK_FILE"
    if [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS: lockf -k keeps the lock file, -t 5 times out after 5 seconds
        lockf -k -t 5 "$LOCK_FILE" "$@"
    else
        # Linux: flock -w 5 waits up to 5 seconds, -x is exclusive lock
        flock -w 5 -x "$LOCK_FILE" "$@"
    fi
}
