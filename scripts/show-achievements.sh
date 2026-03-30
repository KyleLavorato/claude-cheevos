#!/usr/bin/env bash
# show-achievements.sh - Display achievements with locked/unlocked status
#
# Usage:
#   show-achievements.sh                  Interactive filter menu (when run in terminal)
#   show-achievements.sh --all    / -a    Show all achievements
#   show-achievements.sh --unlocked / -u  Show only unlocked achievements
#   show-achievements.sh --locked / -l    Show only locked achievements
#
#   Level filters (combinable with the above):
#   show-achievements.sh --beginner      / -B  Beginner only
#   show-achievements.sh --intermediate  / -I  Intermediate only
#   show-achievements.sh --experienced   / -E  Experienced only
#   show-achievements.sh --master        / -M  Master only
#
# Locked achievements display current progress toward their threshold [current/max].

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

# ─── Parse CLI flags ──────────────────────────────────────────────────────────
FILTER="all"        # all | unlocked | locked
FILTER_SET=false
LEVEL_FILTER="all"  # all | beginner | intermediate | experienced | master | impossible
LEVEL_FILTER_SET=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a|--all)           FILTER="all";          FILTER_SET=true;       shift ;;
        -u|--unlocked)      FILTER="unlocked";     FILTER_SET=true;       shift ;;
        -l|--locked)        FILTER="locked";       FILTER_SET=true;       shift ;;
        -B|--beginner)      LEVEL_FILTER="beginner";      LEVEL_FILTER_SET=true; shift ;;
        -I|--intermediate)  LEVEL_FILTER="intermediate";  LEVEL_FILTER_SET=true; shift ;;
        -E|--experienced)   LEVEL_FILTER="experienced";   LEVEL_FILTER_SET=true; shift ;;
        -M|--master)        LEVEL_FILTER="master";        LEVEL_FILTER_SET=true; shift ;;
        -S|--secret)        LEVEL_FILTER="secret";        LEVEL_FILTER_SET=true; shift ;;
        -h|--help)
            sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            printf "Unknown option: %s\nUsage: %s [--all|-u|-l] [--beginner|-B|-I|-E|-M]\n" \
                "$1" "$(basename "$0")" >&2
            exit 1
            ;;
    esac
done

# ─── Interactive filter menu (only when stdin and stdout are both terminals) ──
if [[ "$FILTER_SET" == "false" ]] && [[ -t 0 ]] && [[ -t 1 ]]; then
    printf "\n${BOLD}Show which achievements?${RESET}\n"
    PS3="Choice: "
    select opt in "All" "Unlocked only" "Locked only"; do
        case "$REPLY" in
            1) FILTER="all";      break ;;
            2) FILTER="unlocked"; break ;;
            3) FILTER="locked";   break ;;
            *) printf "Invalid — showing all.\n"; FILTER="all"; break ;;
        esac
    done
fi

if [[ "$LEVEL_FILTER_SET" == "false" ]] && [[ -t 0 ]] && [[ -t 1 ]]; then
    printf "\n${BOLD}Filter by skill level?${RESET}\n"
    PS3="Choice: "
    select opt in "All levels" "Beginner" "Intermediate" "Experienced" "Master" "Secret"; do
        case "$REPLY" in
            1) LEVEL_FILTER="all";          break ;;
            2) LEVEL_FILTER="beginner";     break ;;
            3) LEVEL_FILTER="intermediate"; break ;;
            4) LEVEL_FILTER="experienced";  break ;;
            5) LEVEL_FILTER="master";       break ;;
            6) LEVEL_FILTER="secret";       break ;;
            *) printf "Invalid — showing all levels.\n"; LEVEL_FILTER="all"; break ;;
        esac
    done
fi

# ─── Load data ────────────────────────────────────────────────────────────────
STATE=$(cat "$STATE_FILE")
DEFS=$(cat "$DEFS_FILE")

SCORE=$(printf '%s' "$STATE"               | jq -r '.score // 0')
UNLOCKED_IDS=$(printf '%s' "$STATE"        | jq -c '.unlocked')
UNLOCK_TIMES=$(printf '%s' "$STATE"        | jq -c '.unlock_times // {}')
UNLOCKED_COUNT=$(printf '%s' "$UNLOCKED_IDS" | jq 'length')
TOTAL_COUNT=$(printf '%s' "$DEFS"          | jq '.achievements | length')

# ─── Header ───────────────────────────────────────────────────────────────────
FILTER_LABEL=""
case "$FILTER" in
    unlocked) FILTER_LABEL="unlocked" ;;
    locked)   FILTER_LABEL="locked"   ;;
esac

LEVEL_LABEL=""
if [[ "$LEVEL_FILTER" != "all" ]]; then
    LEVEL_LABEL="$LEVEL_FILTER"
fi

COMBINED_LABEL=""
if [[ -n "$FILTER_LABEL" && -n "$LEVEL_LABEL" ]]; then
    COMBINED_LABEL="  ${DIM}(${FILTER_LABEL} · ${LEVEL_LABEL})${RESET}"
elif [[ -n "$FILTER_LABEL" ]]; then
    COMBINED_LABEL="  ${DIM}(${FILTER_LABEL} only)${RESET}"
elif [[ -n "$LEVEL_LABEL" ]]; then
    COMBINED_LABEL="  ${DIM}(${LEVEL_LABEL} only)${RESET}"
fi

printf "\n${BOLD}🏆  Claude Cheevos${RESET}%b\n" "$COMBINED_LABEL"
printf "Score: ${YELLOW}%s pts${RESET}  ·  %s/%s unlocked\n\n" \
    "$SCORE" "$UNLOCKED_COUNT" "$TOTAL_COUNT"

# ─── Category display order ───────────────────────────────────────────────────
declare -a CATS=(
    "sessions:Sessions"
    "files:Files"
    "shell:Shell"
    "search:Search"
    "mcp:MCP Integrations"
    "plan_mode:Plan Mode"
    "tokens:Token Consumption"
    "commands:Commands & Skills"
    "context:Context & Compaction"
    "specs:API Specs"
    "reviews:Code Reviews"
    "tests:Testing"
    "misc:Miscellaneous"
    "rank:Rank Achievements"
)

# ─── Render each category ─────────────────────────────────────────────────────
for entry in "${CATS[@]}"; do
    cat_id="${entry%%:*}"
    cat_label="${entry##*:}"

    CAT_JSON=$(printf '%s' "$DEFS" | \
        jq -c --arg c "$cat_id" '[.achievements[] | select(.category == $c)]')
    [[ $(printf '%s' "$CAT_JSON" | jq 'length') -eq 0 ]] && continue

    # Collect lines for this category so we can skip the header if all filtered out
    LINES=()
    while IFS= read -r ach; do
        id=$(          printf '%s' "$ach" | jq -r '.id')
        name=$(        printf '%s' "$ach" | jq -r '.name')
        pts=$(         printf '%s' "$ach" | jq -r '.points')
        desc=$(        printf '%s' "$ach" | jq -r '.description')
        counter=$(     printf '%s' "$ach" | jq -r '.condition.counter')
        threshold=$(   printf '%s' "$ach" | jq -r '.condition.threshold')
        skill_level=$( printf '%s' "$ach" | jq -r '.skill_level // "beginner"')

        is_unlocked=$(printf '%s' "$UNLOCKED_IDS" | \
            jq --arg id "$id" 'index($id) != null')
        current=$(printf '%s' "$STATE" | \
            jq -r --arg c "$counter" '.counters[$c] // 0')

        # Apply unlock filter
        [[ "$FILTER" == "unlocked" && "$is_unlocked" == "false" ]] && continue
        [[ "$FILTER" == "locked"   && "$is_unlocked" == "true"  ]] && continue

        # Apply level filter
        [[ "$LEVEL_FILTER" != "all" && "$skill_level" != "$LEVEL_FILTER" ]] && continue

        pts_str="+${pts} pts"
        if [[ "$is_unlocked" == "true" ]]; then
            unlock_date=$(printf '%s' "$UNLOCK_TIMES" | \
                jq -r --arg id "$id" '.[$id] // "" | if . != "" then .[0:10] else "" end')
            if [[ -n "$unlock_date" ]]; then
                LINES+=("$(printf "  ${GREEN}✅${RESET}  %-26s ${YELLOW}%-10s${RESET}  %s  ${DIM}· %s${RESET}" \
                    "$name" "$pts_str" "$desc" "$unlock_date")")
            else
                LINES+=("$(printf "  ${GREEN}✅${RESET}  %-26s ${YELLOW}%-10s${RESET}  %s" \
                    "$name" "$pts_str" "$desc")")
            fi
        elif [[ "$skill_level" == "secret" ]]; then
            # Secret achievement — hide description and progress until unlocked
            LINES+=("$(printf "  🔮  %-26s ${YELLOW}%-10s${RESET}  ${DIM}???${RESET}" \
                "$name" "$pts_str")")
        elif [[ "$threshold" == "null" ]]; then
            # Rank achievements — no counter progress to show
            LINES+=("$(printf "  🔒  %-26s %-10s  ${DIM}%s${RESET}" \
                "$name" "$pts_str" "$desc")")
        else
            LINES+=("$(printf "  🔒  %-26s %-10s  ${DIM}%s  [%s/%s]${RESET}" \
                "$name" "$pts_str" "$desc" "$current" "$threshold")")
        fi
    done < <(printf '%s' "$CAT_JSON" | jq -c '.[]')

    # Skip category entirely if nothing passed the filter
    [[ ${#LINES[@]} -eq 0 ]] && continue

    printf "${BOLD}${CYAN}%s${RESET}\n" "$cat_label"
    for line in "${LINES[@]}"; do
        printf "%b\n" "$line"
    done
    echo ""
done
