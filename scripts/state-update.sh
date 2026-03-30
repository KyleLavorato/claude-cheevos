#!/usr/bin/env bash
# state-update.sh - Atomic state updater, called under lock by hook scripts
#
# Required environment variables (exported by the calling hook):
#   _STATE_FILE         - path to state.json
#   _DEFS_FILE          - path to definitions.json
#   _NOTIFICATIONS_FILE - path to notifications.json
#   _COUNTER_UPDATES    - JSON object of counter increments, e.g. '{"bash_calls": 1}'
#
# Optional environment variables:
#   _COUNTER_SETS       - JSON object of counter values to SET (not increment),
#                         e.g. '{"streak_days": 1, "last_session_epoch": 19800}'
#   _NEW_MODEL          - model name string; if not already in models_used, appends it
#                         and increments unique_models_used counter
#   _SESSION_ID         - session ID to record as last_session_model_check (used by
#                         stop.sh to avoid re-reading transcript every turn)
#   _UPDATE_CHECK_EPOCH - unix epoch timestamp to record as last_update_check_epoch
#                         (used by check-updates.sh for rate limiting)

set -euo pipefail

# Read current state
STATE=$(cat "$_STATE_FILE")

# Apply counter increments and update timestamp
NEW_STATE=$(printf '%s' "$STATE" | jq \
    --argjson updates "$_COUNTER_UPDATES" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    .counters |= reduce ($updates | to_entries[]) as $e (
        .;
        .[$e.key] = ((.[$e.key] // 0) + $e.value)
    ) |
    .last_updated = $ts
')

# Apply counter sets (absolute values, used for streak tracking)
if [[ -n "${_COUNTER_SETS:-}" ]]; then
    NEW_STATE=$(printf '%s' "$NEW_STATE" | jq \
        --argjson sets "$_COUNTER_SETS" '
        .counters |= reduce ($sets | to_entries[]) as $e (.;
            .[$e.key] = $e.value)
    ')
fi

# Track a newly seen model — only added to models_used if not already present,
# which also increments unique_models_used for achievement checking.
if [[ -n "${_NEW_MODEL:-}" ]]; then
    NEW_STATE=$(printf '%s' "$NEW_STATE" | jq \
        --arg model "$_NEW_MODEL" '
        if ((.models_used // []) | index($model)) == null then
            .models_used = ((.models_used // []) + [$model]) |
            .counters.unique_models_used = ((.counters.unique_models_used // 0) + 1)
        else .
        end
    ')
fi

# Record the session ID so stop.sh can skip re-reading the transcript next turn
if [[ -n "${_SESSION_ID:-}" ]]; then
    NEW_STATE=$(printf '%s' "$NEW_STATE" | jq \
        --arg sid "$_SESSION_ID" '
        .last_session_model_check = $sid
    ')
fi

# Record update check timestamp (used by check-updates.sh for rate limiting)
if [[ -n "${_UPDATE_CHECK_EPOCH:-}" ]]; then
    NEW_STATE=$(printf '%s' "$NEW_STATE" | jq \
        --argjson epoch "$_UPDATE_CHECK_EPOCH" '
        .last_update_check_epoch = $epoch
    ')
fi

# Check for newly unlocked achievements (compare updated counters against definitions)
# Supports condition types:
#   counter           (default) - counter >= threshold
#   all_of_level                - all non-rank achievements of .level are unlocked
#   all_unlocked                - every achievement except this one is unlocked
#   all_tutorial                - all tutorial-flagged achievements are unlocked
#   unlocked_count_gte          - total unlocked achievements >= threshold
NEWLY_UNLOCKED=$(jq -n \
    --argjson state "$NEW_STATE" \
    --slurpfile defs "$_DEFS_FILE" '
    $defs[0].achievements | map(
        . as $ach |
        select(
            ($state.unlocked | index($ach.id) | not) and
            (
                if ($ach.condition.type // "counter") == "all_of_level" then
                    (($ach.condition | has("requires") | not) or
                     ($state.unlocked | index($ach.condition.requires) != null)) and
                    ($defs[0].achievements
                     | map(select(.skill_level == $ach.condition.level and .category != "rank"))
                     | map(.id)
                     | map(. as $id | $state.unlocked | index($id) != null)
                     | all)
                elif ($ach.condition.type // "counter") == "all_unlocked" then
                    (($ach.condition | has("requires") | not) or
                     ($state.unlocked | index($ach.condition.requires) != null)) and
                    ($defs[0].achievements
                     | map(select(.id != $ach.id))
                     | map(.id)
                     | map(. as $id | $state.unlocked | index($id) != null)
                     | all)
                elif ($ach.condition.type // "counter") == "all_tutorial" then
                    ($defs[0].achievements
                     | map(select(.tutorial == true))
                     | map(.id)
                     | map(. as $id | $state.unlocked | index($id) != null)
                     | all)
                elif ($ach.condition.type // "counter") == "unlocked_count_gte" then
                    ($state.unlocked | length) >= $ach.condition.threshold
                else
                    (($state.counters[$ach.condition.counter] // 0) >= $ach.condition.threshold)
                end
            )
        )
    )
')

COUNT=$(printf '%s' "$NEWLY_UNLOCKED" | jq 'length')

if [[ "$COUNT" -gt 0 ]]; then
    # Add newly unlocked IDs to state, record timestamps, and accumulate score
    NEW_STATE=$(printf '%s' "$NEW_STATE" | jq \
        --argjson n "$NEWLY_UNLOCKED" \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
        .unlocked += ($n | map(.id)) |
        .score += ($n | map(.points) | add // 0) |
        .unlock_times = ((.unlock_times // {}) + ($n | map({(.id): $ts}) | add // {}))
    ')

    # Append to notification queue
    EXISTING_NOTIFS="[]"
    [[ -f "$_NOTIFICATIONS_FILE" ]] && EXISTING_NOTIFS=$(cat "$_NOTIFICATIONS_FILE")
    NEW_NOTIFS=$(jq -n \
        --argjson e "$EXISTING_NOTIFS" \
        --argjson n "$NEWLY_UNLOCKED" '$e + $n')
    TMP=$(mktemp "${_NOTIFICATIONS_FILE}.XXXXXX")
    printf '%s' "$NEW_NOTIFS" > "$TMP"
    mv "$TMP" "$_NOTIFICATIONS_FILE"
fi

# Write updated state atomically via temp file + mv (same filesystem = atomic rename)
TMP=$(mktemp "${_STATE_FILE}.XXXXXX")
printf '%s' "$NEW_STATE" > "$TMP"
mv "$TMP" "$_STATE_FILE"
