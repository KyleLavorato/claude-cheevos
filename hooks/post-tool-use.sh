#!/usr/bin/env bash
# post-tool-use.sh - PostToolUse hook (runs async via "async": true in settings)
#
# Fires after each tool call succeeds. Increments the appropriate counter
# based on the tool name, then calls cheevos update.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=../scripts/lib.sh
source "$SCRIPT_DIR/../scripts/lib.sh"

# Guard: if the binary is not installed, exit gracefully
[[ -x "$CHEEVOS" ]] || exit 0

INPUT=$(cat)
TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // ""')

# Map tool name to counter increments
COUNTER_UPDATES=''
case "$TOOL" in
    Write)
        FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
        FILE_BASENAME=$(basename "$FILE_PATH")

        IS_COMMAND=false
        IS_SPEC=false
        IS_CLAUDE_MD=false
        IS_TEST=false

        if [[ "$FILE_PATH" == *"/.claude/commands/"*.md ]]; then
            IS_COMMAND=true
        fi

        if [[ "$FILE_BASENAME" == "CLAUDE.md" ]]; then
            IS_CLAUDE_MD=true
        fi

        # Detect test files by filename pattern (cross-language)
        case "$FILE_BASENAME" in
            *.test.js|*.test.ts|*.test.jsx|*.test.tsx|\
            *.spec.js|*.spec.ts|*.spec.jsx|*.spec.tsx|\
            *_test.go|*_test.py|*_test.rb|*_test.rs|\
            *Test.java|*Tests.java|*Spec.java)
                IS_TEST=true ;;
        esac
        if [[ "$IS_TEST" == "false" ]]; then
            if [[ "$FILE_BASENAME" == test_*.py || "$FILE_BASENAME" == test_*.js ||
                  "$FILE_BASENAME" == test_*.ts ]]; then
                IS_TEST=true
            fi
        fi

        # Detect API spec files by name or location (/spec(s)/ dirs)
        case "$FILE_BASENAME" in
            openapi.*|swagger.*|asyncapi.*|api-spec.*)
                IS_SPEC=true ;;
        esac
        if [[ "$IS_SPEC" == "false" ]]; then
            if [[ "$FILE_PATH" == */spec/*.yaml || "$FILE_PATH" == */spec/*.yml ||
                  "$FILE_PATH" == */spec/*.json || "$FILE_PATH" == */specs/*.yaml ||
                  "$FILE_PATH" == */specs/*.yml || "$FILE_PATH" == */specs/*.json ]]; then
                IS_SPEC=true
            fi
        fi

        COUNTER_UPDATES='{"files_written": 1}'
        if [[ "$IS_COMMAND" == "true" ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"commands_created": 1}')
        fi
        if [[ "$IS_SPEC" == "true" ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"spec_files_written": 1}')
        fi
        if [[ "$IS_CLAUDE_MD" == "true" ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"claude_md_written": 1}')
        fi
        if [[ "$IS_TEST" == "true" ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"test_files_written": 1}')
        fi
        if printf '%s' "$FILE_BASENAME" | grep -qi "^readme"; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"readme_reads": 1}')
        fi
        if [[ "$FILE_BASENAME" == *.html || "$FILE_BASENAME" == *.htm ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"html_files_written": 1}')
        fi
        ;;
    Edit)
        FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
        FILE_BASENAME=$(basename "$FILE_PATH")
        COUNTER_UPDATES='{"files_written": 1}'
        if printf '%s' "$FILE_BASENAME" | grep -qi "^readme"; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"readme_reads": 1}')
        fi
        NEW_STRING=$(printf '%s' "$INPUT" | jq -r '.tool_input.new_string // ""')
        if printf '%s' "$NEW_STRING" | grep -qi "TODO\|FIXME"; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"todo_comments_added": 1}')
        fi
        ;;
    MultiEdit)
        COUNTER_UPDATES='{"files_written": 1}'
        EDIT_PATHS=$(printf '%s' "$INPUT" | jq -r '.tool_input.edits[]?.file_path // ""' 2>/dev/null || echo "")
        if printf '%s' "$EDIT_PATHS" | grep -qi "^readme\|/readme" 2>/dev/null; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"readme_reads": 1}')
        fi
        if printf '%s' "$EDIT_PATHS" | grep -qiE '\.(test|spec)\.(js|ts|jsx|tsx)$|_test\.(go|py|rb|rs)$|Tests?\.java$|Spec\.java$' 2>/dev/null; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"test_files_written": 1}')
        fi
        ;;
    Bash)
        CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
        COUNTER_UPDATES='{"bash_calls": 1}'
        if [[ "$CMD" == "sudo "* || "$CMD" == *" sudo "* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"sudo_calls": 1}')
        fi
        if [[ "$CMD" == *"git commit"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"git_commits": 1}')
        fi
        if [[ "$CMD" == *"gh pr create"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"pull_requests": 1}')
        fi
        if [[ "$CMD" == *"git push"* ]]; then
            if [[ "$CMD" == *"--force"* && "$CMD" != *"--force-with-lease"* ]] || \
               [[ "$CMD" =~ (^|[[:space:]])-f([[:space:]]|$) ]]; then
                COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"force_pushes": 1}')
            fi
        fi
        if [[ "$CMD" == *"kill -9"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"kill9_calls": 1}')
        fi
        if [[ "$CMD" == *".pptx"* || "$CMD" == *"python-pptx"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"pptx_created": 1}')
        fi
        if [[ "$CMD" == *"claude -p"* || "$CMD" == *"claude --print"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"claude_pipe_mode": 1}')
        fi
        if [[ "$CMD" == *"claude"* && "$CMD" == *"--verbose"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"claude_verbose": 1}')
        fi
        if [[ "$CMD" == *pytest* || "$CMD" == *"npm test"* || "$CMD" == *"npx jest"* ||
              "$CMD" == *"npx vitest"* || "$CMD" == *"go test"* || "$CMD" == *"cargo test"* ||
              "$CMD" == *"dotnet test"* || "$CMD" == *rspec* || "$CMD" == *"mvn test"* ||
              "$CMD" == *"gradle test"* || "$CMD" == *"./gradlew test"* ||
              "$CMD" == *"python -m pytest"* || "$CMD" == *"yarn test"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"test_runs": 1}')
        fi
        ;;
    Read)
        FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // ""')
        FILE_BASENAME=$(basename "$FILE_PATH")
        COUNTER_UPDATES='{"files_read": 1}'
        if [[ "$FILE_PATH" == *"/.claude/achievements/"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"self_reads": 1}')
        fi
        if printf '%s' "$FILE_BASENAME" | grep -qi "^readme"; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"readme_reads": 1}')
        fi
        EXT="${FILE_BASENAME##*.}"
        case "$EXT" in
            py)          COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"py_files_read": 1}') ;;
            c|cpp|h|hpp) COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"c_files_read": 1}') ;;
            go)          COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"go_files_read": 1}') ;;
            rs)          COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"rs_files_read": 1}') ;;
            sh|bash|zsh) COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"sh_files_read": 1}') ;;
            java)        COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"java_files_read": 1}') ;;
        esac
        ;;
    WebSearch|WebFetch)
        COUNTER_UPDATES='{"web_searches": 1}'
        ;;
    Glob|Grep)
        COUNTER_UPDATES='{"glob_grep_calls": 1}'
        ;;
    Skill)
        SKILL_NAME=$(printf '%s' "$INPUT" | jq -r '.tool_input.skill // ""')
        COUNTER_UPDATES='{"skill_calls": 1}'
        if printf '%s' "$SKILL_NAME" | grep -qi "review" 2>/dev/null; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"code_reviews": 1}')
        fi
        ;;
    Task)
        COUNTER_UPDATES='{"task_calls": 1}'
        ;;
    ExitPlanMode)
        COUNTER_UPDATES='{"plan_mode_sessions": 1}'
        ;;
    mcp__github__*)
        COUNTER_UPDATES='{"github_mcp_calls": 1, "total_mcp_calls": 1}'
        if [[ "$TOOL" == *"create_pull_request"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"pull_requests": 1}')
        fi
        if [[ "$TOOL" == *"pull_request_review_write"* ]]; then
            REVIEW_METHOD=$(printf '%s' "$INPUT" | jq -r '.tool_input.method // ""')
            if [[ "$REVIEW_METHOD" == "submit_pending" ]]; then
                COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"code_reviews": 1}')
            fi
        fi
        ;;
    mcp__confluence__*)
        COUNTER_UPDATES='{"jira_mcp_calls": 1, "total_mcp_calls": 1}'
        if [[ "$TOOL" == *"createConfluencePage"* || "$TOOL" == *"updateConfluencePage"* ]]; then
            COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"confluence_published": 1}')
        fi
        ;;
    mcp__*)
        COUNTER_UPDATES='{"total_mcp_calls": 1}'
        ;;
    *)
        # Untracked tool - nothing to do
        exit 0
        ;;
esac

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
