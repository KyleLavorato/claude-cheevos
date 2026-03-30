#!/usr/bin/env bash
# learning-path.sh - Guided tutorial path for Claude Code achievements
#
# Shows all achievements marked "tutorial": true in definitions.json,
# in the order they appear in the definitions file.
# To change the tutorial set, add or remove "tutorial": true from definitions.json.
#
# Usage: bash learning-path.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=./lib.sh
source "$SCRIPT_DIR/lib.sh"

init_state

# ─── ANSI colours (suppressed when stdout is not a terminal) ──────────────────
if [[ -t 1 ]]; then
    BOLD='\033[1m'
    DIM='\033[2m'
    GREEN='\033[32m'
    YELLOW='\033[33m'
    CYAN='\033[36m'
    RESET='\033[0m'
else
    BOLD=''; DIM=''; GREEN=''; YELLOW=''; CYAN=''; RESET=''
fi

# ─── Tips (keyed by achievement ID) ──────────────────────────────────────────
# Bash 3.2 compatible: use a case statement instead of associative arrays
get_tip() {
    case "$1" in
        first_session)        echo "Just open your terminal and run 'claude' to start your first session." ;;
        session_10)           echo "Keep using Claude Code daily — sessions accumulate quickly!" ;;
        web_search_first)     echo "Ask Claude a question that needs current info: 'What's the latest version of Node.js?'" ;;
        back_again)           echo "Resume a past session: run 'claude --resume' or type /resume inside Claude Code." ;;
        files_written_10)     echo "Ask Claude to create files: 'Create a utils.py with a helper function'" ;;
        laying_down_the_law)  echo "Ask Claude: 'Create a CLAUDE.md in this project with instructions for working on this codebase'" ;;
        spec_first)           echo "Ask Claude to design an API spec first: 'Create an OpenAPI spec for a user auth service'" ;;
        files_read_100)       echo "Ask Claude to read and analyze code: 'Explain what this file does' on any source file." ;;
        bash_calls_50)        echo "Ask Claude to run shell commands: 'Run the tests and show me the output'" ;;
        git_er_done)          echo "Ask Claude to commit your work: 'Stage and commit these changes with a good message'" ;;
        glob_grep_50)         echo "Ask Claude to search your codebase: 'Find all files that import React'" ;;
        web_search_25)        echo "Ask research questions regularly: 'What are the best practices for X?'" ;;
        tokens_100k)          echo "Just keep using Claude — tokens accumulate naturally with regular use." ;;
        spring_cleaning)      echo "Type /compact inside Claude Code to manually compact the conversation context." ;;
        github_first)         echo "Ask Claude about a GitHub repo: 'Show me the open PRs in this repo'" ;;
        pull_request_pioneer) echo "Ask Claude to open a PR for you: 'Create a pull request for this branch'" ;;
        jira_first)           echo "Ask Claude to look up a Jira ticket: 'What's the status of PROJ-123?'" ;;
        delegation_station)   echo "Give Claude a broad research task — Claude will launch a sub-agent automatically." ;;
        plan_mode_first)      echo "Ask Claude to plan before implementing: 'Plan how you would add auth to this app'" ;;
        plan_mode_10)         echo "Use plan mode for any significant feature — it leads to better outcomes." ;;
        *)                    echo "" ;;
    esac
}

# ─── Load data ────────────────────────────────────────────────────────────────
STATE=$(cat "$STATE_FILE")
DEFS=$(cat "$DEFS_FILE")

# ─── Build PATH_IDS from tutorial-flagged achievements (definition file order) ─
PATH_IDS=()
while IFS= read -r id; do
    PATH_IDS+=("$id")
done < <(printf '%s' "$DEFS" | jq -r '.achievements[] | select(.tutorial == true) | .id')

PATH_COUNT=${#PATH_IDS[@]}
TOTAL_PTS=$(printf '%s' "$DEFS" | jq '[.achievements[] | select(.tutorial == true) | .points] | add // 0')

# Single jq @tsv pass to index all achievement definitions
# Stored as newline-delimited TSV rows; looked up via grep+cut (Bash 3.2 compatible)
ACH_TSV=$(printf '%s' "$DEFS" | jq -r '
    .achievements[] |
    [.id, .name, .description, (.points | tostring),
     .condition.counter, (.condition.threshold | tostring)] |
    @tsv')

# Lookup helper: get_ach <id> <field_number>
#   field 1=id, 2=name, 3=description, 4=points, 5=counter, 6=threshold
get_ach() {
    printf '%s\n' "$ACH_TSV" | grep "^${1}	" | cut -f"$2"
}

UNLOCKED_IDS=$(printf '%s' "$STATE" | jq -c '.unlocked')

# ─── Compute path progress ────────────────────────────────────────────────────
EARNED_PTS=0
COMPLETED=0
LOCKED_IDS=()

for id in "${PATH_IDS[@]}"; do
    is_unlocked=$(printf '%s' "$UNLOCKED_IDS" | jq --arg id "$id" 'index($id) != null')
    if [[ "$is_unlocked" == "true" ]]; then
        COMPLETED=$(( COMPLETED + 1 ))
        pts=$(get_ach "$id" 4)
        EARNED_PTS=$(( EARNED_PTS + pts ))
    else
        LOCKED_IDS+=("$id")
    fi
done

# ─── Build UP_NEXT list (first 3 locked) + newline-delimited set for lookup ──
UP_NEXT_LIST=()
UP_NEXT_SET=""
for id in "${LOCKED_IDS[@]}"; do
    if (( ${#UP_NEXT_LIST[@]} < 3 )); then
        UP_NEXT_LIST+=("$id")
        UP_NEXT_SET="${UP_NEXT_SET}${id}
"
    else
        break
    fi
done

# ─── Header + progress bar ────────────────────────────────────────────────────
printf "\n${BOLD}🗺️   Claude Cheevos — Tutorial${RESET}\n"

BAR=""
for (( i=0; i<20; i++ )); do
    if (( EARNED_PTS * 20 > i * TOTAL_PTS )); then
        BAR="${BAR}█"
    else
        BAR="${BAR}░"
    fi
done

printf "%s/%s complete  ·  ${YELLOW}[%s]${RESET}  %s/%s pts\n" \
    "$COMPLETED" "$PATH_COUNT" "$BAR" "$EARNED_PTS" "$TOTAL_PTS"

# ─── Up Next section ──────────────────────────────────────────────────────────
printf "\n${BOLD}⭐  Up Next${RESET}\n"
printf -- "────────────────────────────────────────────────────────────\n"

if [[ ${#UP_NEXT_LIST[@]} -eq 0 ]]; then
    printf "  🎉 All tutorial achievements complete!\n"
else
    for id in "${UP_NEXT_LIST[@]}"; do
        name=$(get_ach "$id" 2)
        desc=$(get_ach "$id" 3)
        pts=$(get_ach "$id" 4)
        counter=$(get_ach "$id" 5)
        threshold=$(get_ach "$id" 6)
        tip=$(get_tip "$id")

        current=$(printf '%s' "$STATE" | jq -r --arg c "$counter" '.counters[$c] // 0')

        pts_str="+${pts} pts"
        printf "  ${YELLOW}⭐${RESET}  %-26s ${YELLOW}%-10s${RESET}  ${DIM}[%s/%s %s]${RESET}\n" \
            "$name" "$pts_str" "$current" "$threshold" "$counter"
        printf "      %s\n" "$desc"
        if [[ -n "$tip" ]]; then
            printf "      ${CYAN}💡 %s${RESET}\n" "$tip"
        fi
        printf "\n"
    done
fi

# ─── Full Path section ────────────────────────────────────────────────────────
printf "${BOLD}Full Path${RESET}\n"
printf -- "────────────────────────────────────────────────────────────\n"

idx=0
for id in "${PATH_IDS[@]}"; do
    idx=$(( idx + 1 ))
    name=$(get_ach "$id" 2)
    desc=$(get_ach "$id" 3)
    pts=$(get_ach "$id" 4)
    counter=$(get_ach "$id" 5)
    threshold=$(get_ach "$id" 6)
    pts_str="+${pts} pts"

    is_unlocked=$(printf '%s' "$UNLOCKED_IDS" | jq --arg id "$id" 'index($id) != null')

    if [[ "$is_unlocked" == "true" ]]; then
        printf "  ${GREEN}✅${RESET}  %2d. %-24s ${YELLOW}%-10s${RESET}  %s\n" \
            "$idx" "$name" "$pts_str" "$desc"
    elif printf '%s' "$UP_NEXT_SET" | grep -qx "$id"; then
        current=$(printf '%s' "$STATE" | jq -r --arg c "$counter" '.counters[$c] // 0')
        printf "  ${YELLOW}⭐${RESET}  %2d. %-24s ${YELLOW}%-10s${RESET}  ${DIM}[%s/%s]${RESET}\n" \
            "$idx" "$name" "$pts_str" "$current" "$threshold"
    else
        printf "  ${DIM}🔒  %2d. %-24s %-10s  [0/%s]${RESET}\n" \
            "$idx" "$name" "$pts_str" "$threshold"
    fi
done

printf "\n"
