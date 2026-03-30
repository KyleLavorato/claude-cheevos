#!/usr/bin/env bash
# stop.sh - Stop hook (runs synchronously at end of each assistant turn)
#
# 1. Tracks the active model by reading the transcript once per session
#    and updating the models_used list in state.json.
# 2. Drains the notification queue built up by async PostToolUse hooks
#    and outputs a systemMessage JSON blob to notify the user of newly
#    unlocked achievements. Multiple unlocks are batched into one message.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

# Always read stdin — hook input contains session_id and transcript_path
INPUT=$(cat)

# ─── Transcript analysis (model tracking + sorry detection) ──────────────────
SESSION_ID=$(printf '%s' "$INPUT"      | jq -r '.session_id    // ""')
TRANSCRIPT_PATH=$(printf '%s' "$INPUT" | jq -r '.transcript_path // ""')

if [[ -n "$TRANSCRIPT_PATH" && -f "$TRANSCRIPT_PATH" && -f "$STATE_FILE" ]]; then
    LAST_CHECKED=$(jq -r '.last_session_model_check // ""' "$STATE_FILE" 2>/dev/null || echo "")

    # Single tail read — reused for both jq analysis and code review detection
    TAIL_CONTENT=$(tail -c 20000 "$TRANSCRIPT_PATH" 2>/dev/null || echo "")

    # jq pass: extract model, sorry flag, code review quality signals, and whether
    # this turn contained a review-type tool call (any Skill with "review" in the
    # name, or a pull_request_review_write submission).
    TRANSCRIPT_INFO=$(printf '%s' "$TAIL_CONTENT" | jq -rs '
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
            model:      ($last.message.model // ""),
            sorry:         ($text | ascii_downcase | test("sorry")),
            great_question: ($text | ascii_downcase | test("great question")),
            hal_9000:       ($text | ascii_downcase | test("sorry, dave")),
            youre_right:    ($text | ascii_downcase | test("you.?re right|you are right")),
            barnacles:      ($text | ascii_downcase | test("barnacles")),
            twenty_questions: ($user_text | ascii_downcase | test("20 questions|twenty questions")),
            magic_conch:      ($user_text | ascii_downcase | test("help me decide|help me choose|help me make a decision|which should i|what should i (do|pick|choose|use)")),
            inner_machinations: ($user_text | ascii_downcase | test("explain (this |the )?(codebase|code|repo|project)|summarize (this |the )?(codebase|code|repo|project)|give me an overview|walk me through (this |the )?(codebase|code|repo)|how does (this |the )?(codebase|code|project) work")),
            tic_tac_toe: (
                ($user_text | ascii_downcase | test("tic.?tac.?toe")) and
                ($text | ascii_downcase | test("\\bi win\\b|you lose|x wins|o wins|game over|i(.ve)? won"))
            ),
            code_smell: ($user_text | ascii_downcase | test("code smell|code smells|smelly code|smell.*code|code.*smell|bad smell")),
            doctor_run: ($user_text | ascii_downcase | test("^/doctor|\\s/doctor")),
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
                .[] | select(.type == "assistant") | .message.content[]? |
                select(.type == "tool_use" and .name == "Write") |
                ((.input.file_path // "") | test("CLAUDE\\.md$"; "i"))
            ),
            context_high: (($last.message.usage.input_tokens // 0) > 180000),
            output_tokens:  ($last.message.usage.output_tokens // 0),
            lucky:          (($last.message.usage.output_tokens // 0) == 777),
            no_issues:  ($text | ascii_downcase |
                            test("no issues|lgtm|looks good to me|no problems found|no code issues|nothing to flag")),
            many_issues: ($text | test("\\b[2-9][0-9]\\.[ \t]|\\b[1-9][0-9]{2,}\\.[ \t]")),
            code_review_turn: any(
                .[] | select(.type == "assistant") | .message.content[]? |
                select(.type == "tool_use") | (
                    (.name == "Skill" and ((.input.skill // "") | ascii_downcase | test("review"))) or
                    (.name | test("pull_request_review_write"))
                )
            )
        }
    ' 2>/dev/null || echo '{"model":"","sorry":false,"great_question":false,"hal_9000":false,"youre_right":false,"barnacles":false,"twenty_questions":false,"magic_conch":false,"inner_machinations":false,"tic_tac_toe":false,"code_smell":false,"doctor_run":false,"deja_vu":false,"chess":false,"slow_response":false,"wrote_claude_md":false,"context_high":false,"output_tokens":0,"lucky":false,"no_issues":false,"many_issues":false,"code_review_turn":false}')

    MODEL=$(printf '%s' "$TRANSCRIPT_INFO"                | jq -r '.model')
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
    DOCTOR_RUN=$(printf '%s' "$TRANSCRIPT_INFO"           | jq -r '.doctor_run')
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
    NEW_MODEL_VAL=""
    SESSION_ID_VAL=""

    # Model tracking — only once per session
    if [[ -n "$SESSION_ID" && "$SESSION_ID" != "$LAST_CHECKED" && \
          -n "$MODEL" && "$MODEL" != "null" ]]; then
        NEW_MODEL_VAL="$MODEL"
        SESSION_ID_VAL="$SESSION_ID"
    fi

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

    # 20 questions tracking — fires when user message contains "20 questions"
    if [[ "$TWENTY_QUESTIONS" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"twenty_questions_started": 1}')
    fi

    # Magic Conch Shell — fires when user asks Claude to help make a decision
    if [[ "$MAGIC_CONCH" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"magic_conch_used": 1}')
    fi

    # Inner Machinations — fires when user asks Claude to explain or summarize a codebase
    if [[ "$INNER_MACHINATIONS" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"inner_machinations_used": 1}')
    fi

    # Tic tac toe — fires when user plays and Claude wins
    if [[ "$TIC_TAC_TOE" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"lost_tic_tac_toe": 1}')
    fi

    # Code smell — fires when user asks Claude to check for code smells
    if [[ "$CODE_SMELL" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"code_smell_check": 1}')
    fi

    # /doctor command — fires when user runs Claude's diagnostic command
    if [[ "$DOCTOR_RUN" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"doctor_run": 1}')
    fi

    # Deja Vu — user sent the same message as the previous turn
    if [[ "$DEJA_VU" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"deja_vu_sent": 1}')
    fi

    # Chess — fires when user mentions chess
    if [[ "$CHESS" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"chess_started": 1}')
    fi

    # True Vibe Coder — dangerous launch + git commit + PR all in usage history
    _VDANGER=$(jq -r '.counters.dangerous_launches // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    _VCOMMIT=$(jq -r '.counters.git_commits // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    _VPR=$(jq -r '.counters.pull_requests // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    if (( _VDANGER >= 1 && _VCOMMIT >= 1 && _VPR >= 1 )); then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"vibe_code_done": 1}')
    fi

    # But Its Compiling — fires when a response took more than 15 minutes
    if [[ "$SLOW_RESPONSE" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"slow_responses": 1}')
    fi

    # "Write that down" — CLAUDE.md written while context > 90% full (>180k input tokens)
    if [[ "$WROTE_CLAUDE_MD" == "true" && "$CONTEXT_HIGH" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"write_that_down": 1}')
    fi

    # Stack Connector — GitHub MCP + Jira MCP + at least one other MCP server
    # Reads current state (pre-update) to check cumulative counters
    _GH=$(jq -r '.counters.github_mcp_calls // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    _JR=$(jq -r '.counters.jira_mcp_calls // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    _TOT=$(jq -r '.counters.total_mcp_calls // 0' "$STATE_FILE" 2>/dev/null || echo 0)
    if (( _GH >= 1 && _JR >= 1 && _TOT > _GH + _JR )); then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"multi_mcp_used": 1}')
    fi

    # F is for friends — 0.1% random chance each turn (1 in 1000)
    if (( RANDOM % 1000 == 0 )); then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"lucky_friends": 1}')
    fi

    # Lucky 7s — exactly 777 output tokens in the last response
    if [[ "$LUCKY" == "true" ]]; then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"lucky_sessions": 1}')
    fi

    # Token consumption — accumulate output tokens per turn as tokens_consumed
    if (( OUTPUT_TOKENS > 0 )); then
        COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq --argjson t "$OUTPUT_TOKENS" '. + {"tokens_consumed": $t}')
    fi

    # Code review quality — only when this turn had a codeReview skill call
    if [[ "$CODE_REVIEW_TURN" == "true" ]]; then
        if [[ "$NO_ISSUES" == "true" ]]; then
            COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"perfect_reviews": 1}')
        fi
        if [[ "$MANY_ISSUES" == "true" ]]; then
            COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"thorough_reviews": 1}')
        fi
    fi

    # Only write to state if there's something to update
    if [[ -n "$NEW_MODEL_VAL" || "$COUNTER_EXTRA" != '{}' ]]; then
        init_state
        export _STATE_FILE="$STATE_FILE"
        export _DEFS_FILE="$DEFS_FILE"
        export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
        export _COUNTER_UPDATES="$COUNTER_EXTRA"
        [[ -n "$NEW_MODEL_VAL"  ]] && export _NEW_MODEL="$NEW_MODEL_VAL"
        [[ -n "$SESSION_ID_VAL" ]] && export _SESSION_ID="$SESSION_ID_VAL"
        with_lock bash "$SCRIPTS_DIR/state-update.sh"
        unset _NEW_MODEL _SESSION_ID
    fi
fi

# Fast path: skip if notification queue is absent or empty
if [[ ! -f "$NOTIFICATIONS_FILE" ]]; then
    exit 0
fi

QUEUE_COUNT=$(jq 'length' "$NOTIFICATIONS_FILE" 2>/dev/null || echo 0)
if [[ "$QUEUE_COUNT" == "0" ]]; then
    exit 0
fi

# Drain the notification queue under lock into a temp file
TEMP_NOTIFS=$(mktemp /tmp/cheevos-notifs.XXXXXX.json)
export _NOTIFICATIONS_FILE="$NOTIFICATIONS_FILE"
export _TEMP_NOTIFS="$TEMP_NOTIFS"

with_lock bash -c '
    count=$(jq "length" "$_NOTIFICATIONS_FILE" 2>/dev/null || echo 0)
    if [[ "$count" -gt 0 ]]; then
        cp "$_NOTIFICATIONS_FILE" "$_TEMP_NOTIFS"
        printf "[]" > "$_NOTIFICATIONS_FILE"
    fi
'

# Verify we actually got something (race: another Stop hook could have drained first)
if [[ ! -s "$TEMP_NOTIFS" ]]; then
    rm -f "$TEMP_NOTIFS"
    exit 0
fi

COUNT=$(jq 'length' "$TEMP_NOTIFS" 2>/dev/null || echo 0)
if [[ "$COUNT" == "0" ]]; then
    rm -f "$TEMP_NOTIFS"
    exit 0
fi

# Read current score (no lock needed - display only)
TOTAL_SCORE=$(jq -r '.score // 0' "$STATE_FILE" 2>/dev/null || echo 0)

# Build achievement list lines
ACHIEVEMENT_LINES=$(jq -r '
    map("  [" + .name + " +" + (.points | tostring) + " pts] " + .description)
    | join("\n")
' "$TEMP_NOTIFS")

# Fire system notification (macOS and WSL/Windows)
if [[ "$(uname -s)" == "Darwin" ]]; then
    # macOS: native notification via osascript
    if [[ "$COUNT" == "1" ]]; then
        _notif_name=$(jq -r '.[0].name' "$TEMP_NOTIFS")
        _notif_pts=$(jq -r '.[0].points | tostring' "$TEMP_NOTIFS")
        _notif_desc=$(jq -r '.[0].description' "$TEMP_NOTIFS")
        osascript -e "display notification \"${_notif_desc} (+${_notif_pts} pts)\" with title \"🏆 Achievement Unlocked!\" subtitle \"${_notif_name}\" sound name \"Glass\""
    else
        _notif_names=$(jq -r '[.[].name] | join(", ")' "$TEMP_NOTIFS")
        osascript -e "display notification \"${_notif_names}\" with title \"🏆 ${COUNT} Achievements Unlocked!\" sound name \"Glass\""
    fi
elif [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL: Windows toast notification via PowerShell
    # Build title and body strings
    if [[ "$COUNT" == "1" ]]; then
        _notif_title="🏆 Achievement Unlocked!"
        _notif_body=$(jq -r '"[" + .[0].name + "] " + .[0].description + " (+" + (.[0].points | tostring) + " pts)"' "$TEMP_NOTIFS")
    else
        _notif_title="🏆 ${COUNT} Achievements Unlocked!"
        _notif_body=$(jq -r '[.[].name] | join(", ")' "$TEMP_NOTIFS")
    fi
    # Write PS script to temp file to avoid shell/PS escaping issues
    # Single quotes in values are doubled for PS single-quoted strings;
    # XML special chars are handled by SecurityElement::Escape inside PS.
    _ps_tmp=$(mktemp /tmp/cheevos-notif.XXXXXX.ps1)
    # Escape single quotes for PS single-quoted strings (double them)
    _ps_title=$(printf '%s' "$_notif_title" | sed "s/'/''/g")
    _ps_body=$(printf '%s' "$_notif_body" | sed "s/'/''/g")
    # Use a quoted heredoc so bash does NOT expand $variables or
    # interpret quotes inside the body — then patch in the two values
    # via sed after writing.
    cat > "$_ps_tmp" << 'PSEOF'
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType=WindowsRuntime] | Out-Null
$title = [System.Security.SecurityElement]::Escape('__TITLE__')
$body  = [System.Security.SecurityElement]::Escape('__BODY__')
$xml   = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml("<toast><visual><binding template='ToastGeneric'><text>$title</text><text>$body</text></binding></visual></toast>")
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Cheevos').Show([Windows.UI.Notifications.ToastNotification]::new($xml))
PSEOF
    # Substitute placeholders with actual values (sed delimiter chosen
    # to avoid clashing with notification text)
    sed -i.bak "s|__TITLE__|${_ps_title}|g;s|__BODY__|${_ps_body}|g" "$_ps_tmp"
    rm -f "${_ps_tmp}.bak"
    _win_ps_tmp=$(wslpath -w "$_ps_tmp")
    powershell.exe -NonInteractive -NoProfile -WindowStyle Hidden -File "$_win_ps_tmp" 2>/dev/null &
    # Clean up temp file after PS has had time to read it
    { sleep 5; rm -f "$_ps_tmp"; } &
fi

rm -f "$TEMP_NOTIFS"

# Build header
if [[ "$COUNT" == "1" ]]; then
    HEADER="🏆 Achievement Unlocked!"
else
    HEADER="🏆 ${COUNT} Achievements Unlocked!"
fi

# Emit systemMessage JSON - Claude Code displays this to the user inline
# jq handles proper JSON escaping of newlines and special characters
jq -n \
    --arg header "$HEADER" \
    --arg lines "$ACHIEVEMENT_LINES" \
    --arg score "$TOTAL_SCORE" \
    '{"systemMessage": ($header + "\n" + $lines + "\nTotal Score: " + $score + " pts")}'
