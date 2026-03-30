#!/usr/bin/env bash
# award.sh - Manually increment a counter (for Easter egg achievements)
#
# Usage: bash award.sh <counter_name>
#
# Claude can call this when a user triggers a special achievement manually,
# e.g.: bash award.sh easter_egg_unlocks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

COUNTER="${1:-}"
if [[ -z "$COUNTER" ]]; then
    printf "Usage: bash award.sh <counter_name>\n" >&2
    exit 1
fi

# Validate that the counter is used by at least one achievement in definitions.json
init_state
VALID=$(jq --arg c "$COUNTER" '[.achievements[] | select(.condition.counter == $c)] | length' "$DEFS_FILE")
if [[ "$VALID" == "0" ]]; then
    printf "Error: '%s' is not a valid achievement counter.\n" "$COUNTER" >&2
    printf "Valid counters can be found in definitions.json.\n" >&2
    exit 1
fi

export _STATE_FILE="$STATE_FILE"
export _DEFS_FILE="$DEFS_FILE"
export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
export _COUNTER_UPDATES="{\"${COUNTER}\": 1}"

with_lock bash "$SCRIPTS_DIR/state-update.sh"

printf "Awarded: %s\n" "$COUNTER"
