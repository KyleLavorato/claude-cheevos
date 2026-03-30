#!/usr/bin/env bash
# tui.sh — Interactive achievement browser for Claude Code Achievement System
#
# Pure bash TUI with arrow-key navigation.  No external deps beyond jq + tput.
# Bash 3.2+ compatible (macOS default shell).
#
# Usage: bash ~/.claude/achievements/scripts/tui.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"
init_state

# ─── Constants ────────────────────────────────────────────────────────────────
HEADER_H=3   # top border + title + divider
FOOTER_H=2   # divider + keybindings

CAT_ORDER="sessions files shell search mcp plan_mode tokens commands context specs reviews tests misc rank"

# Category display names — accessed via cat_name() helper (bash 3.2 compatible)
cat_name() {
    case "$1" in
        sessions)     printf 'Sessions' ;;
        files)        printf 'Files' ;;
        shell)        printf 'Shell' ;;
        search)       printf 'Search' ;;
        mcp)          printf 'MCP' ;;
        plan_mode)    printf 'Plan Mode' ;;
        tokens)       printf 'Tokens' ;;
        commands)     printf 'Commands' ;;
        context)      printf 'Context' ;;
        specs)        printf 'Specs' ;;
        reviews)      printf 'Reviews' ;;
        tests)        printf 'Tests' ;;
        misc)         printf 'Misc' ;;
        rank)         printf 'Rank' ;;
        *)            printf '%s' "$1" ;;
    esac
}

# ─── Terminal setup / teardown ────────────────────────────────────────────────
_SAVED_STTY=$(stty -g 2>/dev/null || true)

cleanup() {
    # Restore raw stty
    if [[ -n "$_SAVED_STTY" ]]; then
        stty "$_SAVED_STTY" 2>/dev/null || true
    fi
    # Show cursor, exit alternate screen
    printf '\033[?25h\033[?1049l'
}
trap cleanup EXIT INT TERM

# Enter alternate screen buffer, hide cursor
printf '\033[?1049h\033[?25l'

TERM_H=$(tput lines)
TERM_W=$(tput cols)

handle_resize() {
    TERM_H=$(tput lines)
    TERM_W=$(tput cols)
    NEED_REDRAW=1
}
trap handle_resize WINCH

# Put terminal in raw/cbreak mode so arrow keys arrive immediately
stty -echo -icanon min 1 time 0 2>/dev/null || true

# ─── Colors (gracefully degrade if tput lacks color support) ──────────────────
_ncolors=$(tput colors 2>/dev/null || echo 0)
if [[ "$_ncolors" -ge 8 ]]; then
    C_RESET=$(tput sgr0)
    C_BOLD=$(tput bold)
    C_REV=$(tput rev)
    C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3)
    C_CYAN=$(tput setaf 6)
    C_DIM=$(tput setaf 8 2>/dev/null || tput setaf 7)
    C_HEADER=$(tput setaf 4)   # blue for header bar
else
    C_RESET="" C_BOLD="" C_REV="" C_GREEN="" C_YELLOW="" C_CYAN="" C_DIM="" C_HEADER=""
fi

# ─── Data loading ─────────────────────────────────────────────────────────────
if [[ ! -f "$STATE_FILE" || ! -f "$DEFS_FILE" ]]; then
    printf '\033[?25h\033[?1049l'
    stty "$_SAVED_STTY" 2>/dev/null || true
    echo "ERROR: Achievement files not found. Run: bash install.sh" >&2
    exit 1
fi

SCORE=$(jq -r '.score // 0' "$STATE_FILE")
UNLOCKED_COUNT=$(jq -r '.unlocked | length' "$STATE_FILE")
TOTAL_COUNT=$(jq -r '.achievements | length' "$DEFS_FILE")

# Build flat item list via jq.
# Each output line is pipe-delimited:
#   C|cat_id|unlocked_in_cat|total_in_cat
#   A|id|name|pts|cat|level|is_unlocked(0/1)|unlock_date|description|counter|current|threshold
ITEM_LINES=$(jq -r -s '
    .[0] as $s |
    .[1].achievements as $achs |
    ($s.unlocked // []) as $unlocked |
    ($s.unlock_times // {}) as $times |
    ($s.counters // {}) as $counters |
    ["sessions","files","shell","search","mcp","plan_mode","tokens","commands",
     "context","specs","reviews","tests","misc","rank"][] | . as $cat |
    ($achs | map(select(.category == $cat))) as $cat_achs |
    ($cat_achs | length) as $cat_total |
    if $cat_total > 0 then
        (
            ($cat_achs | map(select(.id as $id | ($unlocked | index($id)) != null)) | length) as $cat_unl |
            "C|\($cat)|\($cat_unl)|\($cat_total)"
        ),
        (
            $cat_achs[] | . as $a |
            ($a.id as $id | ($unlocked | index($id)) != null) as $is_unl |
            ($times[$a.id] // "" | if . != "" then .[0:10] else "" end) as $udate |
            ($counters[$a.condition.counter // ""] // 0) as $cur |
            ($a.condition.threshold // 0) as $thr |
            "A|\($a.id)|\($a.name)|\($a.points)|\($a.category)|\($a.skill_level)|\(if $is_unl then 1 else 0 end)|\($udate)|\($a.description)|\($a.condition.counter // "")|\($cur)|\($thr)"
        )
    else empty end
' "$STATE_FILE" "$DEFS_FILE")

# Load into indexed array
ITEMS=()
while IFS= read -r _line; do
    ITEMS+=("$_line")
done <<< "$ITEM_LINES"

N_ITEMS=${#ITEMS[@]}

if [[ "$N_ITEMS" -eq 0 ]]; then
    printf '\033[?25h\033[?1049l'
    stty "$_SAVED_STTY" 2>/dev/null || true
    echo "No achievements found." >&2
    exit 1
fi

# Find indices of all selectable items (type A) for cursor movement
SEL_INDICES=()
for _i in $(seq 0 $(( N_ITEMS - 1 ))); do
    if [[ "${ITEMS[$_i]:0:1}" == "A" ]]; then
        SEL_INDICES+=("$_i")
    fi
done
N_SEL=${#SEL_INDICES[@]}

# ─── State ────────────────────────────────────────────────────────────────────
SEL_POS=0           # index within SEL_INDICES (the cursor position)
SCROLL=0            # first visible ITEMS index
VIEW="list"         # "list" or "detail"
NEED_REDRAW=1

# ─── Drawing helpers ──────────────────────────────────────────────────────────

# Move cursor to row R (1-based), column 1; clear to end of line
goto_row() { printf '\033[%d;1H\033[K' "$1"; }

# Print a horizontal rule of width TERM_W
hline() {
    local char="${1:-─}"
    local w="$TERM_W"
    local i=0
    local out=""
    while [[ "$i" -lt "$w" ]]; do
        out="${out}${char}"
        i=$(( i + 1 ))
    done
    printf '%s' "$out"
}

# Pad/truncate string $1 to exactly $2 visible chars (ASCII-safe, no wide chars)
# Wide unicode chars (emoji) counted as 2 columns — we pass them pre-formatted.
fit() {
    local s="$1"
    local w="$2"
    local len="${#s}"
    if [[ "$len" -ge "$w" ]]; then
        printf '%s' "${s:0:$w}"
    else
        printf '%-*s' "$w" "$s"
    fi
}

render_header() {
    local title=" 🏆  Claude Code Achievements"
    local stats=" ${SCORE} pts  ·  ${UNLOCKED_COUNT}/${TOTAL_COUNT} unlocked "
    local mid_pad=$(( TERM_W - ${#title} - ${#stats} ))
    if [[ "$mid_pad" -lt 1 ]]; then mid_pad=1; fi
    local padding
    padding=$(printf '%*s' "$mid_pad" '')

    goto_row 1
    printf '%s%s%s%s%s%s\n' \
        "$C_HEADER$C_BOLD" "$title" "$C_RESET$C_DIM" "$padding" "$C_BOLD$stats" "$C_RESET"
    goto_row 2
    printf '%s%s%s' "$C_DIM" "$(hline '─')" "$C_RESET"
}

render_footer() {
    local row=$(( TERM_H - 1 ))
    local row2="$TERM_H"

    goto_row "$row"
    printf '%s%s%s' "$C_DIM" "$(hline '─')" "$C_RESET"

    goto_row "$row2"
    if [[ "$VIEW" == "list" ]]; then
        printf '%s  ↑↓ Navigate   Enter: Details   q: Quit%s' "$C_DIM" "$C_RESET"
    else
        printf '%s  Esc/Backspace: Back to list   q: Quit%s' "$C_DIM" "$C_RESET"
    fi
}

# ─── List view ────────────────────────────────────────────────────────────────

# Return the ITEMS index of the currently selected achievement
cursor_item_idx() {
    printf '%s' "${SEL_INDICES[$SEL_POS]}"
}

# Adjust SCROLL so the cursor stays in the viewport
clamp_scroll() {
    local content_h=$(( TERM_H - HEADER_H - FOOTER_H ))
    local cidx
    cidx=$(cursor_item_idx)

    # Scroll down if cursor is below viewport
    while [[ "$cidx" -ge $(( SCROLL + content_h )) ]]; do
        SCROLL=$(( SCROLL + 1 ))
    done

    # Scroll up if cursor is above viewport
    while [[ "$cidx" -lt "$SCROLL" ]]; do
        SCROLL=$(( SCROLL - 1 ))
    done
}

render_list() {
    local content_h=$(( TERM_H - HEADER_H - FOOTER_H ))
    local cidx
    cidx=$(cursor_item_idx)

    local row=$(( HEADER_H + 1 ))
    local end_row=$(( HEADER_H + content_h ))
    local item_idx="$SCROLL"

    while [[ "$row" -le "$end_row" ]]; do
        goto_row "$row"

        if [[ "$item_idx" -ge "$N_ITEMS" ]]; then
            printf ''  # blank line already cleared by goto_row
        else
            local line="${ITEMS[$item_idx]}"
            local type="${line:0:1}"

            if [[ "$type" == "C" ]]; then
                # Category header
                local cat_id
                cat_id=$(printf '%s' "$line" | cut -d'|' -f2)
                local cat_unl
                cat_unl=$(printf '%s' "$line" | cut -d'|' -f3)
                local cat_tot
                cat_tot=$(printf '%s' "$line" | cut -d'|' -f4)
                local cname
                cname=$(cat_name "$cat_id")

                local label="── ${cname} (${cat_unl}/${cat_tot}) "
                local trail_len=$(( TERM_W - ${#label} ))
                local trail=""
                if [[ "$trail_len" -gt 0 ]]; then
                    local i=0
                    while [[ "$i" -lt "$trail_len" ]]; do
                        trail="${trail}─"
                        i=$(( i + 1 ))
                    done
                fi
                printf '%s%s%s%s%s' "$C_CYAN$C_BOLD" "$label" "$C_RESET$C_DIM" "$trail" "$C_RESET"

            else
                # Achievement row
                local name pts level is_unl udate desc counter cur thr
                name=$(printf '%s' "$line" | cut -d'|' -f3)
                pts=$(printf '%s' "$line" | cut -d'|' -f4)
                level=$(printf '%s' "$line" | cut -d'|' -f6)
                is_unl=$(printf '%s' "$line" | cut -d'|' -f7)
                desc=$(printf '%s' "$line" | cut -d'|' -f9)
                counter=$(printf '%s' "$line" | cut -d'|' -f10)
                cur=$(printf '%s' "$line" | cut -d'|' -f11)
                thr=$(printf '%s' "$line" | cut -d'|' -f12)

                local selected=0
                if [[ "$item_idx" -eq "$cidx" ]]; then selected=1; fi

                # Status icon (each emoji is 2 terminal columns wide)
                local icon
                if [[ "$is_unl" == "1" ]]; then
                    icon="✅"
                elif [[ "$level" == "secret" ]]; then
                    icon="🔮"
                else
                    icon="🔒"
                fi

                # Progress tag for locked items
                local prog=""
                if [[ "$is_unl" == "0" && "$thr" != "0" && "$level" != "secret" ]]; then
                    prog=" [${cur}/${thr}]"
                fi

                # Name (max 22 visible chars)
                local name_fit
                name_fit=$(fit "${name:0:22}" 22)

                # Points (right-aligned in 8 chars)
                local pts_str="+${pts}pts"
                local pts_fit
                pts_fit=$(fit "$pts_str" 8)

                # Layout: sel(2) + icon(2cols) + sp(2) + name(22) + sp(2) + pts(8) + sp(2) + desc... + prog
                # Fixed visible width: 2+2+2+22+2+8+2 = 40
                local fixed_w=40
                local desc_avail=$(( TERM_W - fixed_w - ${#prog} - 1 ))
                if [[ "$desc_avail" -lt 4 ]]; then desc_avail=4; fi

                local desc_shown
                if [[ "${#desc}" -gt "$desc_avail" ]]; then
                    desc_shown="${desc:0:$(( desc_avail - 1 ))}…"
                else
                    desc_shown="$desc"
                fi

                # Selector marker
                local sel_marker="  "
                if [[ "$selected" -eq 1 ]]; then sel_marker="▶ "; fi

                # Name color
                local nc
                if [[ "$is_unl" == "1" ]]; then
                    nc="$C_GREEN$C_BOLD"
                elif [[ "$level" == "secret" ]]; then
                    nc="$C_DIM"
                else
                    nc="$C_BOLD"
                fi

                # Selection highlight: invert the whole row
                local row_start=""
                if [[ "$selected" -eq 1 ]]; then
                    row_start="$C_REV"
                fi

                # Print row; \033[K fills remainder with current attrs
                # (reverse video for selected, normal otherwise)
                # Layout: rev  sel(2)  icon(2W)  (2sp)  name(22)  (2sp)  pts(8)  (2sp)  desc…prog
                printf '%s%s%s  %s  %s  %s\033[K%s' \
                    "$row_start" \
                    "$sel_marker" \
                    "$icon" \
                    "${nc}${name_fit}${C_RESET}${row_start}" \
                    "$pts_fit" \
                    "${desc_shown}${C_DIM}${prog}${C_RESET}${row_start}" \
                    "$C_RESET"
            fi

            item_idx=$(( item_idx + 1 ))
        fi

        row=$(( row + 1 ))
    done
}

# ─── Detail view ──────────────────────────────────────────────────────────────

render_detail() {
    local cidx
    cidx=$(cursor_item_idx)
    local line="${ITEMS[$cidx]}"

    local id name pts cat level is_unl udate desc counter cur thr
    id=$(printf '%s' "$line" | cut -d'|' -f2)
    name=$(printf '%s' "$line" | cut -d'|' -f3)
    pts=$(printf '%s' "$line" | cut -d'|' -f4)
    cat=$(printf '%s' "$line" | cut -d'|' -f5)
    level=$(printf '%s' "$line" | cut -d'|' -f6)
    is_unl=$(printf '%s' "$line" | cut -d'|' -f7)
    udate=$(printf '%s' "$line" | cut -d'|' -f8)
    desc=$(printf '%s' "$line" | cut -d'|' -f9)
    counter=$(printf '%s' "$line" | cut -d'|' -f10)
    cur=$(printf '%s' "$line" | cut -d'|' -f11)
    thr=$(printf '%s' "$line" | cut -d'|' -f12)

    local icon status_str
    if [[ "$is_unl" == "1" ]]; then
        icon="✅"
        status_str="${C_GREEN}Unlocked${C_RESET}"
    elif [[ "$level" == "secret" ]]; then
        icon="🔮"
        status_str="${C_DIM}Secret${C_RESET}"
    else
        icon="🔒"
        status_str="Locked"
    fi

    local content_h=$(( TERM_H - HEADER_H - FOOTER_H ))
    local row=$(( HEADER_H + 1 ))

    # Blank out the content area
    local r="$row"
    while [[ "$r" -le $(( row + content_h - 1 )) ]]; do
        goto_row "$r"
        r=$(( r + 1 ))
    done

    local pad="    "   # 4-space indent

    goto_row "$row"
    printf '%s%s%s  %s%s%s     +%s pts%s' \
        "$pad" "$icon" "  " \
        "$C_BOLD" "$name" "$C_RESET" \
        "$C_YELLOW$C_BOLD" "$pts" "$C_RESET"
    row=$(( row + 2 ))

    # Description (wrapped to TERM_W - 8)
    local wrap_w=$(( TERM_W - 8 ))
    if [[ "$wrap_w" -lt 20 ]]; then wrap_w=20; fi
    local desc_line=""
    local word
    for word in $desc; do
        if [[ $(( ${#desc_line} + ${#word} + 1 )) -gt "$wrap_w" ]]; then
            goto_row "$row"
            printf '%s%s%s' "$pad" "$desc_line" "$C_RESET"
            row=$(( row + 1 ))
            desc_line="$word"
        else
            if [[ -z "$desc_line" ]]; then
                desc_line="$word"
            else
                desc_line="${desc_line} ${word}"
            fi
        fi
    done
    if [[ -n "$desc_line" ]]; then
        goto_row "$row"
        printf '%s%s' "$pad" "$desc_line"
        row=$(( row + 1 ))
    fi

    row=$(( row + 1 ))

    # Metadata table
    local field_w=14

    goto_row "$row"
    printf '%s%s%-*s%s%s' "$pad" "$C_DIM" "$field_w" "Category:" "$C_RESET" "$(cat_name "$cat")"
    row=$(( row + 1 ))

    goto_row "$row"
    local level_display
    level_display="$(printf '%s' "$level" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "$level" | cut -c2-)"
    printf '%s%s%-*s%s%s' "$pad" "$C_DIM" "$field_w" "Skill Level:" "$C_RESET" "$level_display"
    row=$(( row + 1 ))

    goto_row "$row"
    printf '%s%s%-*s%s%s' "$pad" "$C_DIM" "$field_w" "Status:" "$C_RESET" "$status_str"
    row=$(( row + 1 ))

    if [[ "$is_unl" == "1" && -n "$udate" ]]; then
        goto_row "$row"
        printf '%s%s%-*s%s%s' "$pad" "$C_DIM" "$field_w" "Unlocked:" "$C_RESET" "$udate"
        row=$(( row + 1 ))
    fi

    if [[ "$level" != "secret" && -n "$counter" && "$thr" != "0" ]]; then
        goto_row "$row"
        printf '%s%s%-*s%s%s / %s' \
            "$pad" "$C_DIM" "$field_w" "Progress:" "$C_RESET" "$cur" "$thr"
        row=$(( row + 1 ))

        # Progress bar
        local bar_w=$(( TERM_W - 8 - field_w - 4 ))
        if [[ "$bar_w" -gt 40 ]]; then bar_w=40; fi
        if [[ "$bar_w" -gt 4 && "$thr" -gt 0 ]]; then
            local filled=$(( cur * bar_w / thr ))
            if [[ "$filled" -gt "$bar_w" ]]; then filled="$bar_w"; fi
            local empty=$(( bar_w - filled ))
            local bar="["
            local k=0
            while [[ "$k" -lt "$filled" ]]; do bar="${bar}█"; k=$(( k + 1 )); done
            k=0
            while [[ "$k" -lt "$empty" ]]; do bar="${bar}░"; k=$(( k + 1 )); done
            bar="${bar}]"
            goto_row "$row"
            printf '%s%s%s%s' "$pad$pad" "$C_GREEN" "$bar" "$C_RESET"
            row=$(( row + 1 ))
        fi
    fi

    goto_row "$row"
    printf '%s%s(achievement %d of %d)%s' "$pad" "$C_DIM" "$(( SEL_POS + 1 ))" "$N_SEL" "$C_RESET"
}

# ─── Full screen redraw ───────────────────────────────────────────────────────
redraw() {
    # Clear screen
    printf '\033[2J'
    render_header
    if [[ "$VIEW" == "list" ]]; then
        clamp_scroll
        render_list
    else
        render_detail
    fi
    render_footer
    NEED_REDRAW=0
}

# ─── Key reading ─────────────────────────────────────────────────────────────
read_key() {
    KEY=""
    local k1 k2 k3 k4
    IFS= read -r -s -n1 k1
    if [[ "$k1" == $'\x1b' ]]; then
        # Could be escape alone or the start of a sequence
        IFS= read -r -s -n1 -t 0.05 k2 || true
        if [[ "$k2" == "[" ]]; then
            IFS= read -r -s -n1 -t 0.05 k3 || true
            # Some sequences have a 4th byte (e.g. Page Up: [5~)
            case "$k3" in
                [0-9]) IFS= read -r -s -n1 -t 0.05 k4 || true; KEY="${k1}${k2}${k3}${k4}" ;;
                *)     KEY="${k1}${k2}${k3}" ;;
            esac
        else
            KEY="${k1}${k2}"
        fi
    else
        KEY="$k1"
    fi
}

# ─── Navigation helpers ───────────────────────────────────────────────────────
move_up() {
    if [[ "$SEL_POS" -gt 0 ]]; then
        SEL_POS=$(( SEL_POS - 1 ))
        NEED_REDRAW=1
    fi
}

move_down() {
    if [[ "$SEL_POS" -lt $(( N_SEL - 1 )) ]]; then
        SEL_POS=$(( SEL_POS + 1 ))
        NEED_REDRAW=1
    fi
}

page_up() {
    local content_h=$(( TERM_H - HEADER_H - FOOTER_H ))
    local jump=$(( content_h - 2 ))
    if [[ "$jump" -lt 1 ]]; then jump=1; fi
    SEL_POS=$(( SEL_POS - jump ))
    if [[ "$SEL_POS" -lt 0 ]]; then SEL_POS=0; fi
    NEED_REDRAW=1
}

page_down() {
    local content_h=$(( TERM_H - HEADER_H - FOOTER_H ))
    local jump=$(( content_h - 2 ))
    if [[ "$jump" -lt 1 ]]; then jump=1; fi
    SEL_POS=$(( SEL_POS + jump ))
    if [[ "$SEL_POS" -ge "$N_SEL" ]]; then SEL_POS=$(( N_SEL - 1 )); fi
    NEED_REDRAW=1
}

# ─── Main loop ────────────────────────────────────────────────────────────────
while true; do
    if [[ "$NEED_REDRAW" -eq 1 ]]; then
        redraw
    fi

    read_key

    case "$KEY" in
        # Quit
        q|Q)
            exit 0
            ;;

        # Arrow up / k
        $'\x1b[A'|k|K)
            if [[ "$VIEW" == "list" ]]; then
                move_up
            fi
            ;;

        # Arrow down / j
        $'\x1b[B'|j|J)
            if [[ "$VIEW" == "list" ]]; then
                move_down
            fi
            ;;

        # Page Up
        $'\x1b[5~')
            if [[ "$VIEW" == "list" ]]; then
                page_up
            fi
            ;;

        # Page Down
        $'\x1b[6~')
            if [[ "$VIEW" == "list" ]]; then
                page_down
            fi
            ;;

        # Home — jump to first item
        $'\x1b[H'|$'\x1b[1~')
            if [[ "$VIEW" == "list" ]]; then
                SEL_POS=0
                SCROLL=0
                NEED_REDRAW=1
            fi
            ;;

        # End — jump to last item
        $'\x1b[F'|$'\x1b[4~')
            if [[ "$VIEW" == "list" ]]; then
                SEL_POS=$(( N_SEL - 1 ))
                NEED_REDRAW=1
            fi
            ;;

        # Enter — open detail view
        $'\r'|$'\n'|$'\x0d')
            if [[ "$VIEW" == "list" ]]; then
                VIEW="detail"
                NEED_REDRAW=1
            else
                VIEW="list"
                NEED_REDRAW=1
            fi
            ;;

        # Escape or Backspace — back to list
        $'\x1b'|$'\x7f'|$'\x08')
            if [[ "$VIEW" == "detail" ]]; then
                VIEW="list"
                NEED_REDRAW=1
            fi
            ;;

        # Previous achievement (detail view)
        $'\x1b[D'|h|H)
            if [[ "$VIEW" == "detail" ]]; then
                move_up
            fi
            ;;

        # Next achievement (detail view)
        $'\x1b[C'|l|L)
            if [[ "$VIEW" == "detail" ]]; then
                move_down
            fi
            ;;
    esac
done
