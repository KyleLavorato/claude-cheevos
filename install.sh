#!/usr/bin/env bash
# install.sh - Claude Code Achievement System installer
#
# Idempotent: safe to run multiple times (upgrades scripts, preserves state).
# Merges hooks and statusLine into ~/.claude/settings.json without overwriting
# any existing configuration.
#
# Usage: bash install.sh

set -euo pipefail

# ─── Argument parsing ─────────────────────────────────────────────────────────
ARG_TOKEN=""
ARG_API_URL=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --token)   ARG_TOKEN="${2:-}";   shift 2 ;;
        --api-url) ARG_API_URL="${2:-}"; shift 2 ;;
        *) echo "Usage: bash install.sh [--token TOKEN] [--api-url URL]"; exit 1 ;;
    esac
done

VERSION="1.0.0"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ACHIEVEMENTS_DIR="$HOME/.claude/achievements"
SETTINGS="$HOME/.claude/settings.json"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 0: Preflight checks
# ─────────────────────────────────────────────────────────────────────────────

echo "Claude Code Achievement System v${VERSION}"
echo "========================================"

# Dependency check
for cmd in jq bash; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: '$cmd' is required but not found in PATH"
        exit 1
    fi
done

# Claude Code must be installed
if [[ ! -f "$SETTINGS" ]]; then
    echo "ERROR: $SETTINGS not found."
    echo "       Is Claude Code installed? Run 'claude' first to create the config."
    exit 1
fi

# Validate existing settings.json
if ! jq empty "$SETTINGS" 2>/dev/null; then
    echo "ERROR: $SETTINGS contains invalid JSON. Please fix it before installing."
    exit 1
fi

# Detect existing install
INSTALLED_VERSION=""
if [[ -f "$ACHIEVEMENTS_DIR/.version" ]]; then
    INSTALLED_VERSION=$(cat "$ACHIEVEMENTS_DIR/.version")
    if [[ "$INSTALLED_VERSION" == "$VERSION" ]]; then
        echo "Reinstalling v${VERSION} (repair run)..."
    else
        echo "Upgrading from v${INSTALLED_VERSION} → v${VERSION}..."
    fi
else
    echo "Fresh install..."
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Phase 1: Install scripts into ~/.claude/achievements/
# Scripts are copied from the repo so the repo can be removed after install.
# On upgrade: always overwrite scripts, never touch state.json.
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$ACHIEVEMENTS_DIR/hooks"
mkdir -p "$ACHIEVEMENTS_DIR/scripts"

# Hook scripts
cp "$REPO_DIR/hooks/session-start.sh"   "$ACHIEVEMENTS_DIR/hooks/session-start.sh"
cp "$REPO_DIR/hooks/post-tool-use.sh"   "$ACHIEVEMENTS_DIR/hooks/post-tool-use.sh"
cp "$REPO_DIR/hooks/stop.sh"            "$ACHIEVEMENTS_DIR/hooks/stop.sh"
cp "$REPO_DIR/hooks/pre-compact.sh"     "$ACHIEVEMENTS_DIR/hooks/pre-compact.sh"
chmod +x "$ACHIEVEMENTS_DIR/hooks/"*.sh

# Shared scripts
cp "$REPO_DIR/scripts/lib.sh"                "$ACHIEVEMENTS_DIR/scripts/lib.sh"
cp "$REPO_DIR/scripts/state-update.sh"       "$ACHIEVEMENTS_DIR/scripts/state-update.sh"
cp "$REPO_DIR/scripts/statusline-wrapper.sh" "$ACHIEVEMENTS_DIR/scripts/statusline-wrapper.sh"
cp "$REPO_DIR/scripts/seed-state.sh"         "$ACHIEVEMENTS_DIR/scripts/seed-state.sh"
cp "$REPO_DIR/scripts/show-achievements.sh"  "$ACHIEVEMENTS_DIR/scripts/show-achievements.sh"
cp "$REPO_DIR/scripts/learning-path.sh"      "$ACHIEVEMENTS_DIR/scripts/learning-path.sh"
cp "$REPO_DIR/scripts/award.sh"              "$ACHIEVEMENTS_DIR/scripts/award.sh"
cp "$REPO_DIR/scripts/check-updates.sh"      "$ACHIEVEMENTS_DIR/scripts/check-updates.sh"
cp "$REPO_DIR/scripts/verify-install.sh"     "$ACHIEVEMENTS_DIR/scripts/verify-install.sh"
cp "$REPO_DIR/scripts/leaderboard-sync.sh"   "$ACHIEVEMENTS_DIR/scripts/leaderboard-sync.sh"
cp "$REPO_DIR/scripts/auto-update.sh"        "$ACHIEVEMENTS_DIR/scripts/auto-update.sh"
chmod +x "$ACHIEVEMENTS_DIR/scripts/"*.sh

# Achievement definitions (always update from repo to pick up new achievements)
cp "$REPO_DIR/data/definitions.json" "$ACHIEVEMENTS_DIR/definitions.json"

echo "✓ Scripts installed to $ACHIEVEMENTS_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 2: Merge hooks into settings.json (idempotent)
# Checks exact command string before adding to avoid duplicates.
# ─────────────────────────────────────────────────────────────────────────────

SS_CMD="bash $ACHIEVEMENTS_DIR/hooks/session-start.sh"
PT_CMD="bash $ACHIEVEMENTS_DIR/hooks/post-tool-use.sh"
ST_CMD="bash $ACHIEVEMENTS_DIR/hooks/stop.sh"
PC_CMD="bash $ACHIEVEMENTS_DIR/hooks/pre-compact.sh"

TEMP=$(mktemp "$SETTINGS.XXXXXX")

jq \
    --arg ss "$SS_CMD" \
    --arg pt "$PT_CMD" \
    --arg st "$ST_CMD" \
    --arg pc "$PC_CMD" '
    .hooks //= {} |

    # SessionStart: add hook if exact command not already present
    if (.hooks.SessionStart // [] | map(.hooks // [] | map(.command) | any(. == $ss)) | any) then .
    else .hooks.SessionStart += [{"hooks": [{"type": "command", "command": $ss}]}]
    end |

    # PostToolUse: add async hook if exact command not already present
    if (.hooks.PostToolUse // [] | map(.hooks // [] | map(.command) | any(. == $pt)) | any) then .
    else .hooks.PostToolUse += [{"hooks": [{"type": "command", "command": $pt, "async": true}]}]
    end |

    # Stop: add hook if exact command not already present
    if (.hooks.Stop // [] | map(.hooks // [] | map(.command) | any(. == $st)) | any) then .
    else .hooks.Stop += [{"hooks": [{"type": "command", "command": $st}]}]
    end |

    # PreCompact: add hook if exact command not already present
    if (.hooks.PreCompact // [] | map(.hooks // [] | map(.command) | any(. == $pc)) | any) then .
    else .hooks.PreCompact += [{"hooks": [{"type": "command", "command": $pc}]}]
    end
' "$SETTINGS" > "$TEMP"

# Validate before replacing
if ! jq empty "$TEMP" 2>/dev/null; then
    rm -f "$TEMP"
    echo "ERROR: Failed to merge hooks - produced invalid JSON. Aborting."
    exit 1
fi

mv "$TEMP" "$SETTINGS"
echo "✓ Hooks merged into settings.json"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 3: Wrap statusLine command
# Three cases:
#   A) No existing statusLine  → set wrapper, save "" to .original-statusline
#   B) Existing command        → save original, replace with wrapper
#   C) Already wrapped         → skip
# ─────────────────────────────────────────────────────────────────────────────

WRAPPER_CMD="bash $ACHIEVEMENTS_DIR/scripts/statusline-wrapper.sh"
ORIGINAL_SAVE="$ACHIEVEMENTS_DIR/.original-statusline"

CURRENT_CMD=$(jq -r '.statusLine.command // ""' "$SETTINGS")
CURRENT_TYPE=$(jq -r '.statusLine.type // ""' "$SETTINGS")

if [[ "$CURRENT_CMD" == *"achievements/scripts/statusline-wrapper"* ]]; then
    # Case C: already wrapped - skip
    echo "✓ statusLine already wrapped (skipping)"
elif [[ -z "$CURRENT_CMD" ]] || [[ "$CURRENT_TYPE" != "command" ]]; then
    # Case A: no existing command statusLine
    printf '' > "$ORIGINAL_SAVE"
    TEMP=$(mktemp "$SETTINGS.XXXXXX")
    jq --arg cmd "$WRAPPER_CMD" \
       '.statusLine = {"type": "command", "command": $cmd}' \
       "$SETTINGS" > "$TEMP" && mv "$TEMP" "$SETTINGS"
    echo "✓ statusLine configured (no previous statusLine found)"
else
    # Case B: existing command statusLine - save and replace
    printf '%s' "$CURRENT_CMD" > "$ORIGINAL_SAVE"
    TEMP=$(mktemp "$SETTINGS.XXXXXX")
    jq --arg cmd "$WRAPPER_CMD" \
       '.statusLine.command = $cmd' \
       "$SETTINGS" > "$TEMP" && mv "$TEMP" "$SETTINGS"
    echo "✓ statusLine wrapped (original saved to .original-statusline)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Phase 4: Validate final settings.json
# ─────────────────────────────────────────────────────────────────────────────

if ! jq empty "$SETTINGS" 2>/dev/null; then
    echo "ERROR: settings.json is invalid after install. Check $SETTINGS"
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Phase 5: Seed initial state (first install only - preserves state on upgrade)
# ─────────────────────────────────────────────────────────────────────────────

if [[ ! -f "$ACHIEVEMENTS_DIR/state.json" ]]; then
    bash "$REPO_DIR/scripts/seed-state.sh" \
        "$HOME/.claude/stats-cache.json" \
        "$ACHIEVEMENTS_DIR/definitions.json" \
        "$ACHIEVEMENTS_DIR/state.json"
    echo "[]" > "$ACHIEVEMENTS_DIR/notifications.json"
    echo "✓ Initial state seeded"
else
    echo "✓ Existing state preserved (upgrade)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Phase 6: Write version marker
# ─────────────────────────────────────────────────────────────────────────────

printf '%s' "$VERSION" > "$ACHIEVEMENTS_DIR/.version"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 6.5: Leaderboard configuration
# Three cases:
#   A) --token and --api-url both provided  → generate UUID, write enabled conf
#   B) No args, conf already exists         → preserve (upgrade)
#   C) No args, no conf                     → write disabled conf
# ─────────────────────────────────────────────────────────────────────────────

LEADERBOARD_CONF="$ACHIEVEMENTS_DIR/leaderboard.conf"

if [[ -n "$ARG_TOKEN" && -n "$ARG_API_URL" ]]; then
    # Case A: generate UUID (bash 3.2 safe)
    if command -v uuidgen >/dev/null 2>&1; then
        USER_ID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    elif command -v python3 >/dev/null 2>&1; then
        USER_ID=$(python3 -c "import uuid; print(str(uuid.uuid4()))")
    elif [[ -f /proc/sys/kernel/random/uuid ]]; then
        USER_ID=$(cat /proc/sys/kernel/random/uuid)
    else
        USER_ID=$(od -x /dev/urandom | head -1 | awk '{print $2$3"-"$4"-"$5"-"$6"-"$7$8$9}')
    fi
    USERNAME=$(whoami 2>/dev/null || echo "user")
    cat > "$LEADERBOARD_CONF" << EOF
LEADERBOARD_ENABLED=true
USER_ID=${USER_ID}
USERNAME=${USERNAME}
TOKEN=${ARG_TOKEN}
API_URL=${ARG_API_URL}
EOF
    chmod 600 "$LEADERBOARD_CONF"
    echo "✓ Leaderboard configured (user: ${USERNAME}, id: ${USER_ID})"
elif [[ -f "$LEADERBOARD_CONF" ]]; then
    # Case B: existing conf — preserve on upgrade
    echo "✓ Leaderboard config preserved (upgrade)"
else
    # Case C: no args, no conf — write disabled stub
    cat > "$LEADERBOARD_CONF" << 'EOF'
LEADERBOARD_ENABLED=false
USER_ID=
USERNAME=
TOKEN=
API_URL=
EOF
    chmod 600 "$LEADERBOARD_CONF"
    echo "✓ Leaderboard disabled (re-run with --token and --api-url to enable)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "Installation complete!"
echo ""
echo "  Score:       $(jq -r '.score' "$ACHIEVEMENTS_DIR/state.json") pts"
echo "  Achievements: $(jq -r '.unlocked | length' "$ACHIEVEMENTS_DIR/state.json")/$(jq -r '.achievements | length' "$ACHIEVEMENTS_DIR/definitions.json") unlocked"
echo ""
echo "Restart Claude Code for hooks to take effect."
echo ""
echo "View your achievements at any time:"
echo "  bash $ACHIEVEMENTS_DIR/scripts/show-achievements.sh"
