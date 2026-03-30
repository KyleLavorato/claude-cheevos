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
declare -A TIPS
TIPS[first_session]="Just open your terminal and run 'claude' to start your first session."
TIPS[session_10]="Keep using Claude Code daily — sessions accumulate quickly!"
TIPS[web_search_first]="Ask Claude a question that needs current info: 'What's the latest version of Node.js?'"
TIPS[back_again]="Resume a past session: run 'claude --resume' or type /resume inside Claude Code."
TIPS[files_written_10]="Ask Claude to create files: 'Create a utils.py with a helper function'"
TIPS[laying_down_the_law]="Ask Claude: 'Create a CLAUDE.md in this project with instructions for working on this codebase'"
TIPS[spec_first]="Ask Claude to design an API spec first: 'Create an OpenAPI spec for a user auth service'"
TIPS[files_read_100]="Ask Claude to read and analyze code: 'Explain what this file does' on any source file."
TIPS[bash_calls_50]="Ask Claude to run shell commands: 'Run the tests and show me the output'"
TIPS[git_er_done]="Ask Claude to commit your work: 'Stage and commit these changes with a good message'"
TIPS[glob_grep_50]="Ask Claude to search your codebase: 'Find all files that import React'"
TIPS[web_search_25]="Ask research questions regularly: 'What are the best practices for X?'"
TIPS[tokens_100k]="Just keep using Claude — tokens accumulate naturally with regular use."
TIPS[spring_cleaning]="Type /compact inside Claude Code to manually compact the conversation context."
TIPS[github_first]="Ask Claude about a GitHub repo: 'Show me the open PRs in this repo'"
TIPS[pull_request_pioneer]="Ask Claude to open a PR for you: 'Create a pull request for this branch'"
TIPS[jira_first]="Ask Claude to look up a Jira ticket: 'What's the status of PROJ-123?'"
TIPS[delegation_station]="Give Claude a broad research task — Claude will launch a sub-agent automatically."
TIPS[plan_mode_first]="Ask Claude to plan before implementing: 'Plan how you would add auth to this app'"
TIPS[plan_mode_10]="Use plan mode for any significant feature — it leads to better outcomes."

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
declare -A ACH_NAME ACH_DESC ACH_PTS ACH_COUNTER ACH_THRESHOLD

while IFS=$'\t' read -r id name desc pts counter threshold; do
    ACH_NAME[$id]="$name"
    ACH_DESC[$id]="$desc"
    ACH_PTS[$id]="$pts"
    ACH_COUNTER[$id]="$counter"
    ACH_THRESHOLD[$id]="$threshold"
done < <(printf '%s' "$DEFS" | jq -r '
    .achievements[] |
    [.id, .name, .description, (.points | tostring),
     .condition.counter, (.condition.threshold | tostring)] |
    @tsv')

UNLOCKED_IDS=$(printf '%s' "$STATE" | jq -c '.unlocked')

# ─── Compute path progress ────────────────────────────────────────────────────
EARNED_PTS=0
COMPLETED=0
LOCKED_IDS=()

for id in "${PATH_IDS[@]}"; do
    is_unlocked=$(printf '%s' "$UNLOCKED_IDS" | jq --arg id "$id" 'index($id) != null')
    if [[ "$is_unlocked" == "true" ]]; then
        COMPLETED=$(( COMPLETED + 1 ))
        EARNED_PTS=$(( EARNED_PTS + ACH_PTS[$id] ))
    else
        LOCKED_IDS+=("$id")
    fi
done

# ─── Build UP_NEXT_SET (first 3 locked, for O(1) lookup) ─────────────────────
declare -A UP_NEXT_SET
UP_NEXT_LIST=()
for id in "${LOCKED_IDS[@]}"; do
    if (( ${#UP_NEXT_LIST[@]} < 3 )); then
        UP_NEXT_SET[$id]=1
        UP_NEXT_LIST+=("$id")
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
        name="${ACH_NAME[$id]}"
        desc="${ACH_DESC[$id]}"
        pts="${ACH_PTS[$id]}"
        counter="${ACH_COUNTER[$id]}"
        threshold="${ACH_THRESHOLD[$id]}"
        tip="${TIPS[$id]:-}"

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
    name="${ACH_NAME[$id]}"
    desc="${ACH_DESC[$id]}"
    pts="${ACH_PTS[$id]}"
    counter="${ACH_COUNTER[$id]}"
    threshold="${ACH_THRESHOLD[$id]}"
    pts_str="+${pts} pts"

    is_unlocked=$(printf '%s' "$UNLOCKED_IDS" | jq --arg id "$id" 'index($id) != null')

    if [[ "$is_unlocked" == "true" ]]; then
        printf "  ${GREEN}✅${RESET}  %2d. %-24s ${YELLOW}%-10s${RESET}  %s\n" \
            "$idx" "$name" "$pts_str" "$desc"
    elif [[ "${UP_NEXT_SET[$id]+isset}" ]]; then
        current=$(printf '%s' "$STATE" | jq -r --arg c "$counter" '.counters[$c] // 0')
        printf "  ${YELLOW}⭐${RESET}  %2d. %-24s ${YELLOW}%-10s${RESET}  ${DIM}[%s/%s]${RESET}\n" \
            "$idx" "$name" "$pts_str" "$current" "$threshold"
    else
        printf "  ${DIM}🔒  %2d. %-24s %-10s  [0/%s]${RESET}\n" \
            "$idx" "$name" "$pts_str" "$threshold"
    fi
done

printf "\n"
