#!/usr/bin/env bash
# stop.sh - Stop hook (runs synchronously at end of each assistant turn)
#
# 1. Analyses the transcript to detect phrase-based counters.
# 2. Calls cheevos update if anything changed.
# 3. Calls cheevos drain to flush the notification queue and emit systemMessage.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

# Guard: if the binary is not installed, exit gracefully
[[ -x "$CHEEVOS" ]] || exit 0

# Always read stdin — hook input contains session_id and transcript_path
INPUT=$(cat)

# ─── Transcript analysis (phrase detection + code review signals) ────────────
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""')
SESSION_ID=$(printf '%s' "$INPUT" | jq -r '.session_id // ""')

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" && -f "$STATE_FILE" ]]; then

    # Poll for the assistant response, since it may not be flushed to the transcript file
    # by the time the stop hook runs. It's weird, but it's unfortunately true anyway.
    # Use -n 50 to capture enough history even if progress/system entries were appended
    # after the assistant message while we were waiting.
    DEADLINE=$(( $(date +%s) + 2 ))
    while [[ $(date +%s) -lt $DEADLINE ]]; do
        TAIL_CONTENT=$(tail -n 50 "$TRANSCRIPT_PATH" 2>/dev/null || echo "")
        HAS_ASSISTANT=$(printf '%s' "$TAIL_CONTENT" | jq -Rc 'try fromjson catch empty' 2>/dev/null | jq -rs 'any(.[]; .type == "assistant")' 2>/dev/null)
        [[ "$HAS_ASSISTANT" == "true" ]] && break
        sleep 0.1
    done

    # jq pass: extract phrase signals, code review quality signals, and whether
    # this turn contained a review-type tool call (any Skill with "review" in the
    # name, or a pull_request_review_write submission).
    TRANSCRIPT_INFO=$(printf '%s' "$TAIL_CONTENT" | jq -Rc 'try fromjson catch empty' 2>/dev/null | jq -rs '
        ([ .[] | select(.type == "assistant") ] | last) as $last |
        ([ .[] | select(.type == "user") ])           as $all_users |
        ($all_users | last)                           as $last_user |
        (if ($all_users | length) >= 2 then $all_users[-2] else null end) as $prev_user |
        ($last.message.content |
            if type == "array" then [.[] | select(.type == "text") | .text // ""] | join(" ")
            elif type == "string" then .
            else "" end) as $text |
        ($last_user.message.content |
            if type == "array" then [.[] | .text // ""] | join(" ")
            elif type == "string" then .
            else "" end) as $user_text |
        (if $prev_user == null then "" else ($prev_user.message.content |
            if type == "array" then [.[] | .text // ""] | join(" ")
            elif type == "string" then .
            else "" end) end) as $prev_user_text |
        {
            sorry:         ($text | ascii_downcase | test("sorry")),
            great_question: ($text | ascii_downcase | test("great question")),
            hal_9000:       ($text | ascii_downcase | test("sorry, dave")),
            youre_right:    ($text | ascii_downcase | test("you'\''?re right|you are right")),
            barnacles:      ($text | ascii_downcase | test("barnacles")),
            twenty_questions: ($user_text | ascii_downcase | test("20 questions|twenty questions")),
            magic_conch:      ($user_text | ascii_downcase | test("help me decide|help me choose|help me make a decision|which should i|what should i (do|pick|choose|use)")),
            inner_machinations: ($user_text | ascii_downcase | test("explain (this |the )?(codebase|code|repo|project)|summarize (this |the )?(codebase|code|repo|project)|give me an overview|walk me through (this |the )?(codebase|code|repo)|how does (this |the )?(codebase|code|project) work")),
            tic_tac_toe: (
                ($user_text | ascii_downcase | test("tic.?tac.?toe")) and
                ($text | ascii_downcase | test("\\bi win\\b|you lose|x wins|o wins|game over|i('\''ve)? won"))
            ),
            code_smell: (($user_text | ascii_downcase | test("code smell|code smells|smelly code|smell.*code|code.*smell|bad smell")) or ($text | ascii_downcase | test("smell"))),
            deja_vu:    ($user_text != "" and $user_text == $prev_user_text),
            chess:      ($user_text | ascii_downcase | test("chess")),
            slow_response: (
                try (
                    ([ .[] | select(.type == "assistant") ] | last | .timestamp |
                        gsub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) -
                    ([ .[] | select(.type == "user") ] | last | .timestamp |
                        gsub("\\.[0-9]+Z$"; "Z") | fromdateiso8601)
                ) // 0 > 900
            ),
            wrote_claude_md: any(
                .[] | select(.type == "assistant") | .message.content[]?
                | select(.type == "tool_use" and .name == "Write");
                (.input.file_path // "") | test("CLAUDE\\.md$"; "i")
            ),
            context_high: (($last.message.usage.input_tokens // 0) > 180000),
            output_tokens:  ($last.message.usage.output_tokens // 0),
            lucky:          (($last.message.usage.output_tokens // 0) == 777),
            no_issues:  ($text | ascii_downcase |
                            test("no issues|lgtm|looks good to me|no problems found|no code issues|nothing to flag")),
            many_issues: ($text | test("\\b[2-9][0-9]\\.[ \t]|\\b[1-9][0-9]{2,}\\.[ \t]")),
            code_review_turn: any(
                .[] | select(.type == "assistant") | .message.content[]?
                | select(.type == "tool_use");
                (.name == "Skill" and ((.input.skill // "") | ascii_downcase | test("review"))) or
                (.name | test("pull_request_review_write"))
            )
        }
    ' 2>/dev/null || echo '{"sorry":false,"great_question":false,"hal_9000":false,"youre_right":false,"barnacles":false,"twenty_questions":false,"magic_conch":false,"inner_machinations":false,"tic_tac_toe":false,"code_smell":false,"deja_vu":false,"chess":false,"slow_response":false,"wrote_claude_md":false,"context_high":false,"output_tokens":0,"lucky":false,"no_issues":false,"many_issues":false,"code_review_turn":false}')

    SAID_SORRY=$(printf '%s' "$TRANSCRIPT_INFO"           | jq -r '.sorry')
    GREAT_QUESTION=$(printf '%s' "$TRANSCRIPT_INFO"       | jq -r '.great_question')
    HAL_9000=$(printf '%s' "$TRANSCRIPT_INFO"             | jq -r '.hal_9000')
    YOURE_RIGHT=$(printf '%s' "$TRANSCRIPT_INFO"          | jq -r '.youre_right')
    BARNACLES=$(printf '%s' "$TRANSCRIPT_INFO"            | jq -r '.barnacles')
    TWENTY_QUESTIONS=$(printf '%s' "$TRANSCRIPT_INFO"     | jq -r '.twenty_questions')
    MAGIC_CONCH=$(printf '%s' "$TRANSCRIPT_INFO"          | jq -r '.magic_conch')
    INNER_MACHINATIONS=$(printf '%s' "$TRANSCRIPT_INFO"   | jq -r '.inner_machinations')
    TIC_TAC_TOE=$(printf '%s' "$TRANSCRIPT_INFO"          | jq -r '.tic_tac_toe')
    CODE_SMELL=$(printf '%s' "$TRANSCRIPT_INFO"           | jq -r '.code_smell')
    DEJA_VU=$(printf '%s' "$TRANSCRIPT_INFO"              | jq -r '.deja_vu')
    CHESS=$(printf '%s' "$TRANSCRIPT_INFO"                | jq -r '.chess')
    SLOW_RESPONSE=$(printf '%s' "$TRANSCRIPT_INFO"        | jq -r '.slow_response')
    WROTE_CLAUDE_MD=$(printf '%s' "$TRANSCRIPT_INFO"      | jq -r '.wrote_claude_md')
    CONTEXT_HIGH=$(printf '%s' "$TRANSCRIPT_INFO"         | jq -r '.context_high')
    OUTPUT_TOKENS=$(printf '%s' "$TRANSCRIPT_INFO"      | jq -r '.output_tokens')
    LUCKY=$(printf '%s' "$TRANSCRIPT_INFO"              | jq -r '.lucky')
    NO_ISSUES=$(printf '%s' "$TRANSCRIPT_INFO"        | jq -r '.no_issues')
    MANY_ISSUES=$(printf '%s' "$TRANSCRIPT_INFO"      | jq -r '.many_issues')
    CODE_REVIEW_TURN=$(printf '%s' "$TRANSCRIPT_INFO" | jq -r '.code_review_turn')

    COUNTER_EXTRA='{}'
    COUNTER_SETS='{}'

    # Sorry tracking — every turn
    if [[ "$SAID_SORRY" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"apologies": 1}')
    fi

    # "Great question" tracking — every turn
    if [[ "$GREAT_QUESTION" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"great_question_said": 1}')
    fi

    # HAL 9000 phrase tracking — every turn
    if [[ "$HAL_9000" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"hal_9000_said": 1}')
    fi

    # "You're right" tracking — every turn
    if [[ "$YOURE_RIGHT" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"youre_right_said": 1}')
    fi

    # "Barnacles!" tracking — every turn
    if [[ "$BARNACLES" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"barnacles_said": 1}')
    fi

    # 20 questions tracking
    if [[ "$TWENTY_QUESTIONS" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"twenty_questions_started": 1}')
    fi

    # Magic Conch Shell
    if [[ "$MAGIC_CONCH" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"magic_conch_used": 1}')
    fi

    # Inner Machinations
    if [[ "$INNER_MACHINATIONS" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"inner_machinations_used": 1}')
    fi

    # Tic tac toe
    if [[ "$TIC_TAC_TOE" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"lost_tic_tac_toe": 1}')
    fi

    # Code smell
    if [[ "$CODE_SMELL" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"code_smell_check": 1}')
    fi

    # Deja Vu
    if [[ "$DEJA_VU" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"deja_vu_sent": 1}')
    fi

    # Chess
    if [[ "$CHESS" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"chess_started": 1}')
    fi

    # True Vibe Coder — dangerous launch + git commit + PR all in usage history
    _VDANGER=$("$CHEEVOS" get-counter dangerous_launches 2>/dev/null || echo 0)
    _VCOMMIT=$("$CHEEVOS" get-counter git_commits 2>/dev/null || echo 0)
    _VPR=$("$CHEEVOS" get-counter pull_requests 2>/dev/null || echo 0)
    if (( _VDANGER >= 1 && _VCOMMIT >= 1 && _VPR >= 1 )); then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"vibe_code_done": 1}')
    fi

    # But Its Compiling
    if [[ "$SLOW_RESPONSE" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"slow_responses": 1}')
    fi

    # "Write that down"
    if [[ "$WROTE_CLAUDE_MD" == "true" && "$CONTEXT_HIGH" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"write_that_down": 1}')
    fi

    # Stack Connector — GitHub MCP + Jira MCP + at least one other MCP server
    _GH=$("$CHEEVOS" get-counter github_mcp_calls 2>/dev/null || echo 0)
    _JR=$("$CHEEVOS" get-counter jira_mcp_calls 2>/dev/null || echo 0)
    _TOT=$("$CHEEVOS" get-counter total_mcp_calls 2>/dev/null || echo 0)
    if (( _GH >= 1 && _JR >= 1 && _TOT > _GH + _JR )); then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"multi_mcp_used": 1}')
    fi

    # F is for friends — 0.1% random chance each turn (1 in 1000)
    if (( RANDOM % 1000 == 0 )); then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"lucky_friends": 1}')
    fi

    # Lucky 7s
    if [[ "$LUCKY" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"lucky_sessions": 1}')
    fi

    # ─── Per-turn real-time token tracking ─────────────────────────────────────
    # The transcript contains two kinds of assistant entries:
    #   - Streaming chunks:    stop_reason=null,     output_tokens=1-7  (useless)
    #   - Complete turn entry: stop_reason!=null,     output_tokens=real total
    # We find the last complete entry in a 200-line window (wider than the 50-line
    # phrase-detection window because streaming chunks accumulate during the
    # 2-second polling wait and can bury the complete entry).
    #
    # Multi-instance safety: each session writes its last-seen entry timestamp to
    # a per-session file (token_ts_<session_id>).  Concurrent Claude instances each
    # read/write their own file — no shared state for deduplication.  The cheevos
    # binary's flock serialises the actual counter increment so no instance clobbers
    # another.  The stats-cache SET is guarded so it never overrides a counter that
    # is already higher than what the SET would write.

    TOKEN_TS_FILE=""
    LAST_TOKEN_TS=0
    if [[ -n "$SESSION_ID" ]]; then
        TOKEN_TS_FILE="$ACHIEVEMENTS_DIR/token_ts_${SESSION_ID}"
        if [[ -f "$TOKEN_TS_FILE" ]]; then
            LAST_TOKEN_TS=$(cat "$TOKEN_TS_FILE" 2>/dev/null || echo 0)
        fi
    fi

    WIDE_TAIL=$(tail -n 200 "$TRANSCRIPT_PATH" 2>/dev/null || echo "")
    TURN_TOKEN_INFO=$(printf '%s' "$WIDE_TAIL" \
        | jq -Rc 'try fromjson catch empty' 2>/dev/null \
        | jq -rs '
            [.[] | select(.type == "assistant" and .message.stop_reason != null and (.message.usage.output_tokens // 0) > 0)] | last
            | if . == null then {"tokens": 0, "ts": 0}
              else {
                "tokens": (.message.usage.output_tokens // 0),
                "ts": (try (.timestamp | gsub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch 0)
              }
              end
        ' 2>/dev/null || echo '{"tokens":0,"ts":0}')

    TURN_TOKENS=$(printf '%s' "$TURN_TOKEN_INFO" | jq -r '.tokens' || echo 0)
    TURN_TS=$(printf '%s' "$TURN_TOKEN_INFO" | jq -r '.ts' || echo 0)

    # Read current counter value before this update (used for stats-cache guard below).
    CURRENT_TOKENS=$("$CHEEVOS" get-counter tokens_consumed 2>/dev/null || echo 0)

    # Increment by this turn's real output tokens if we haven't counted this entry yet.
    if (( TURN_TS > LAST_TOKEN_TS && TURN_TOKENS > 0 )); then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq --argjson t "$TURN_TOKENS" '. + {"tokens_consumed": $t}')
        # Atomic write via tmp+mv so a crash mid-write never leaves a corrupt file.
        if [[ -n "$TOKEN_TS_FILE" ]]; then
            printf '%d' "$TURN_TS" > "${TOKEN_TS_FILE}.tmp" \
                && mv "${TOKEN_TS_FILE}.tmp" "$TOKEN_TS_FILE" || true
        fi
    fi

    # Stats-cache correction — SET to the historical total only when stats-cache has
    # advanced beyond what per-turn tracking gives after this update.  Guards against:
    #   (a) the SET overriding a freshly-incremented counter (engine applies updates
    #       before sets, but we compute EXPECTED_AFTER_UPDATE defensively), and
    #   (b) the counter going backward if stats-cache is stale.
    STATS_CACHE="$HOME/.claude/stats-cache.json"
    if [[ -f "$STATS_CACHE" ]]; then
        STATS_TOTAL=$(jq '[(.modelUsage // {}) | to_entries[] | .value.outputTokens // 0] | add // 0' "$STATS_CACHE" 2>/dev/null || echo 0)
        EXPECTED_AFTER_UPDATE=$(( CURRENT_TOKENS + TURN_TOKENS ))
        if (( STATS_TOTAL > EXPECTED_AFTER_UPDATE )); then
            COUNTER_SETS=$(printf '{"tokens_consumed": %d}' "$STATS_TOTAL")
        fi
    fi

    # Code review quality
    if [[ "$CODE_REVIEW_TURN" == "true" ]]; then
        if [[ "$NO_ISSUES" == "true" ]]; then
            COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"perfect_reviews": 1}')
        fi
        if [[ "$MANY_ISSUES" == "true" ]]; then
            COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"thorough_reviews": 1}')
        fi
    fi

    # Only write to state if there's something to update
    if [[ "$COUNTER_EXTRA" != '{}' || "$COUNTER_SETS" != '{}' ]]; then
        "$CHEEVOS" init
        export _STATE_FILE="$STATE_FILE"
        export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
        export _COUNTER_UPDATES="$COUNTER_EXTRA"
        export _COUNTER_SETS="$COUNTER_SETS"
        _CHEEVOS_TS=$(cheevos_ts)
        export _CHEEVOS_SIG
        _CHEEVOS_SIG=$(cheevos_sign "$_COUNTER_UPDATES" "$_COUNTER_SETS" "$_CHEEVOS_TS")
        export _CHEEVOS_TS

        "$CHEEVOS" update
    fi
fi

# ─── Drain notification queue and emit systemMessage ─────────────────────────
# cheevos drain writes the systemMessage JSON to stdout and fires OS notifications.
# It exits 0 with no output if the queue was empty.
# When achievements are drained, drain also spawns leaderboard-sync in the
# background automatically — so the sync only happens on actual unlocks.
"$CHEEVOS" drain
