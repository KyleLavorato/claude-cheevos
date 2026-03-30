#!/usr/bin/env bash
# pre-compact.sh - PreCompact hook (runs synchronously before context compaction)
#
# Fires before the context window is compacted. Only processes automatic
# compactions (trigger == "auto"), which means the context window was truly full.
#
# Counters updated:
#   auto_compacts         → incremented on every auto-compact
#   million_context_fills → also incremented if the largest input_tokens value
#                           seen in the transcript is >= 1,000,000

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

INPUT=$(cat)
TRIGGER=$(printf '%s' "$INPUT" | jq -r '.trigger // "manual"')

# Handle manual /compact separately — awards Spring Cleaning, then exits
if [[ "$TRIGGER" == "manual" ]]; then
    init_state
    export _STATE_FILE="$STATE_FILE"
    export _DEFS_FILE="$DEFS_FILE"
    export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
    export _COUNTER_UPDATES='{"manual_compacts": 1}'
    with_lock bash "$SCRIPTS_DIR/state-update.sh"
    exit 0
fi

TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""')

COUNTER_UPDATES='{"auto_compacts": 1}'

# Check if this session filled a 1M-token context window.
# The highest input_tokens value on any assistant message represents the
# largest context size seen during the session.
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
    MAX_CONTEXT=$(jq -rs '
        [.[] | select(.type == "assistant") | .message.usage.input_tokens // 0] |
        max // 0
    ' "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)

    if (( MAX_CONTEXT >= 1000000 )); then
        COUNTER_UPDATES='{"auto_compacts": 1, "million_context_fills": 1}'
    fi
fi

init_state

export _STATE_FILE="$STATE_FILE"
export _DEFS_FILE="$DEFS_FILE"
export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
export _COUNTER_UPDATES="$COUNTER_UPDATES"

with_lock bash "$SCRIPTS_DIR/state-update.sh"

exit 0
