#!/usr/bin/env bash
# seed-state.sh - Creates initial state.json seeded from existing Claude Code stats
#
# Usage: bash seed-state.sh [stats-cache-path] [definitions-path] [output-state-path]
#
# Reads totalSessions from stats-cache.json and pre-unlocks any session-based
# achievements whose threshold is already met. All other counters start at 0.
# If stats-cache.json does not exist, starts fresh with score=0.

set -euo pipefail

STATS_CACHE="${1:-$HOME/.claude/stats-cache.json}"
DEFINITIONS="${2:-$HOME/.claude/achievements/definitions.json}"
OUTPUT="${3:-$HOME/.claude/achievements/state.json}"

# Read totalSessions from stats-cache.json (0 if file missing or field absent)
TOTAL_SESSIONS=0
if [[ -f "$STATS_CACHE" ]]; then
    TOTAL_SESSIONS=$(jq -r '.totalSessions // 0' "$STATS_CACHE" 2>/dev/null || echo 0)
    echo "Found $TOTAL_SESSIONS existing sessions in stats-cache.json"
else
    echo "No stats-cache.json found - starting fresh"
fi

# Build initial state with pre-unlocked session achievements
jq -n \
    --argjson total_sessions "$TOTAL_SESSIONS" \
    --slurpfile defs "$DEFINITIONS" \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    # Find all session-based achievements already earned
    ($defs[0].achievements | map(select(
        .condition.counter == "sessions" and
        .condition.threshold <= $total_sessions
    ))) as $unlocked |

    # Sum their points
    ($unlocked | map(.points) | add // 0) as $score |

    {
        "schema_version": 1,
        "score": $score,
        "counters": {
            "sessions": $total_sessions,
            "files_written": 0,
            "bash_calls": 0,
            "files_read": 0,
            "web_searches": 0,
            "glob_grep_calls": 0,
            "github_mcp_calls": 0,
            "jira_mcp_calls": 0,
            "total_mcp_calls": 0
        },
        "unlocked": ($unlocked | map(.id)),
        "last_updated": $ts
    }
' > "$OUTPUT"

UNLOCKED_COUNT=$(jq '.unlocked | length' "$OUTPUT")
FINAL_SCORE=$(jq '.score' "$OUTPUT")

echo "State seeded:"
echo "  Sessions:             $TOTAL_SESSIONS"
echo "  Achievements unlocked: $UNLOCKED_COUNT"
echo "  Starting score:       $FINAL_SCORE pts"
