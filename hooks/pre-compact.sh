#!/usr/bin/env bash
# pre-compact.sh - PreCompact hook (runs synchronously before context compaction)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

# Guard: if the binary is not installed, exit gracefully
[[ -x "$CHEEVOS" ]] || exit 0

INPUT=$(cat)
TRIGGER=$(printf '%s' "$INPUT" | jq -r '.trigger // "manual"')

# Handle manual /compact separately — awards Spring Cleaning, then exits
if [[ "$TRIGGER" == "manual" ]]; then
    "$CHEEVOS" init
    export _STATE_FILE="$STATE_FILE"
    export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
    export _COUNTER_UPDATES='{"manual_compacts": 1}'
    _CHEEVOS_TS=$(cheevos_ts)
    export _CHEEVOS_SIG
    _CHEEVOS_SIG=$(cheevos_sign "$_COUNTER_UPDATES" "" "" "" "$_CHEEVOS_TS")
    export _CHEEVOS_TS
    "$CHEEVOS" update
    exit 0
fi

TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""')

COUNTER_UPDATES='{"auto_compacts": 1}'

# Check if this session filled a 1M-token context window.
if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" ]]; then
    MAX_CONTEXT=$(jq -rs '
        [.[] | select(.type == "assistant") | .message.usage.input_tokens // 0] |
        max // 0
    ' "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)

    if (( MAX_CONTEXT >= 1000000 )); then
        COUNTER_UPDATES='{"auto_compacts": 1, "million_context_fills": 1}'
    fi
fi

"$CHEEVOS" init

export _STATE_FILE="$STATE_FILE"
export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
export _COUNTER_UPDATES="$COUNTER_UPDATES"

_CHEEVOS_TS=$(cheevos_ts)
export _CHEEVOS_SIG
_CHEEVOS_SIG=$(cheevos_sign "$_COUNTER_UPDATES" "" "" "" "$_CHEEVOS_TS")
export _CHEEVOS_TS

"$CHEEVOS" update

exit 0
