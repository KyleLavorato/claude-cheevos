#!/usr/bin/env bash
# install.sh - Claude Code Achievement System installer (binary edition)
#
# Idempotent: safe to run multiple times (upgrades scripts, preserves state).
# Requires: jq, bash
#
# The cheevos binary must already be compiled and present in the dist/ directory
# alongside this script. Compilation is handled separately by the provider via:
#   make dist
#
# Usage:
#   bash install.sh                           # basic install (leaderboard disabled)
#   bash install.sh --token TOKEN --api-url URL  # install with leaderboard enabled

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

VERSION="2.0.0"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
# dist/ lives at the repo root (one level up from go/)
DIST_DIR="$REPO_DIR/dist"
HOOKS_DIR="$REPO_DIR/hooks"
SCRIPTS_DIR_SRC="$REPO_DIR/scripts"
ACHIEVEMENTS_DIR="$HOME/.claude/achievements"
SETTINGS="$HOME/.claude/settings.json"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 0: Preflight checks
# ─────────────────────────────────────────────────────────────────────────────

echo "Claude Code Achievement System v${VERSION}"
echo "==========================================="

for cmd in jq bash; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: '$cmd' is required but not found in PATH"
        exit 1
    fi
done

# macOS: Auto-install terminal-notifier for enhanced notifications
if [[ "$(uname -s)" == "Darwin" ]]; then
    if ! command -v terminal-notifier >/dev/null 2>&1; then
        echo "Installing terminal-notifier for enhanced notification icons..."
        if command -v brew >/dev/null 2>&1; then
            brew install terminal-notifier || {
                echo "WARNING: Failed to install terminal-notifier via Homebrew"
                echo "         Notifications will fall back to osascript (no custom icons)"
            }
        else
            echo "WARNING: Homebrew not found - cannot auto-install terminal-notifier"
            echo "         Install manually: brew install terminal-notifier"
            echo "         Notifications will fall back to osascript (no custom icons)"
        fi
    else
        echo "✓ terminal-notifier already installed"
    fi
fi

if [[ ! -f "$SETTINGS" ]]; then
    echo "ERROR: $SETTINGS not found. Is Claude Code installed?"
    exit 1
fi

if ! jq empty "$SETTINGS" 2>/dev/null; then
    echo "ERROR: $SETTINGS contains invalid JSON."
    exit 1
fi

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
# Phase 0.5: Select and install the pre-built binary
# ─────────────────────────────────────────────────────────────────────────────

# Detect platform.
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
    x86_64)        ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *)
        echo "ERROR: Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

BINARY_NAME="cheevos-${OS}-${ARCH}"
BINARY_SRC="$DIST_DIR/$BINARY_NAME"

if [[ ! -f "$BINARY_SRC" ]]; then
    echo "ERROR: Pre-built binary not found at $BINARY_SRC"
    echo "       Available binaries in dist/:"
    ls "$DIST_DIR/" 2>/dev/null | sed 's/^/         /' || echo "         (dist/ directory not found)"
    echo ""
    echo "       The binary must be built by the provider before distribution:"
    echo "         make dist"
    exit 1
fi

mkdir -p "$ACHIEVEMENTS_DIR"
cp "$BINARY_SRC" "$ACHIEVEMENTS_DIR/cheevos"
chmod +x "$ACHIEVEMENTS_DIR/cheevos"
echo "✓ Binary installed from dist/$BINARY_NAME"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 1: Install scripts into ~/.claude/achievements/
# ─────────────────────────────────────────────────────────────────────────────

mkdir -p "$ACHIEVEMENTS_DIR/hooks"
mkdir -p "$ACHIEVEMENTS_DIR/scripts"

# Hook scripts (modified versions that call the binary)
cp "$HOOKS_DIR/session-start.sh"   "$ACHIEVEMENTS_DIR/hooks/session-start.sh"
cp "$HOOKS_DIR/post-tool-use.sh"   "$ACHIEVEMENTS_DIR/hooks/post-tool-use.sh"
cp "$HOOKS_DIR/stop.sh"            "$ACHIEVEMENTS_DIR/hooks/stop.sh"
cp "$HOOKS_DIR/pre-compact.sh"     "$ACHIEVEMENTS_DIR/hooks/pre-compact.sh"
chmod +x "$ACHIEVEMENTS_DIR/hooks/"*.sh

# Shared scripts (thin shims that call the binary)
cp "$SCRIPTS_DIR_SRC/lib.sh"                "$ACHIEVEMENTS_DIR/scripts/lib.sh"
cp "$SCRIPTS_DIR_SRC/statusline-wrapper.sh" "$ACHIEVEMENTS_DIR/scripts/statusline-wrapper.sh"
cp "$SCRIPTS_DIR_SRC/seed-state.sh"         "$ACHIEVEMENTS_DIR/scripts/seed-state.sh"
cp "$SCRIPTS_DIR_SRC/show-achievements.sh"  "$ACHIEVEMENTS_DIR/scripts/show-achievements.sh"
cp "$SCRIPTS_DIR_SRC/learning-path.sh"      "$ACHIEVEMENTS_DIR/scripts/learning-path.sh"
cp "$SCRIPTS_DIR_SRC/award.sh"              "$ACHIEVEMENTS_DIR/scripts/award.sh"
cp "$SCRIPTS_DIR_SRC/verify-install.sh"     "$ACHIEVEMENTS_DIR/scripts/verify-install.sh"
chmod +x "$ACHIEVEMENTS_DIR/scripts/"*.sh

# Achievement definitions — always overwritten on install/upgrade so the binary
# always has a current copy to read from disk.
cp "$REPO_DIR/data/definitions.json" "$ACHIEVEMENTS_DIR/definitions.json"

# Uninstall script — copied so /uninstall-achievements slash command can find it
# without needing to know the repo path
cp "$REPO_DIR/uninstall.sh" "$ACHIEVEMENTS_DIR/uninstall.sh"
chmod +x "$ACHIEVEMENTS_DIR/uninstall.sh"

echo "✓ Scripts and definitions installed to $ACHIEVEMENTS_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 1.5: Initialize runtime directory and inject HMAC secret into lib.sh
# ─────────────────────────────────────────────────────────────────────────────

# Initialize runtime directory: creates notifications.json if absent.
# Idempotent — safe on upgrades. The AES key is derived from the binary's
# compile-time HMAC secret — no .key file is created or needed.
"$ACHIEVEMENTS_DIR/cheevos" init

# Extract HMAC secret from the just-built binary and write it into lib.sh.
HMAC_SECRET=$("$ACHIEVEMENTS_DIR/cheevos" print-hmac-secret 2>/dev/null || echo "")
if [[ -z "$HMAC_SECRET" ]]; then
    echo "WARNING: Could not extract HMAC secret from binary. Hook validation disabled."
else
    if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' "s|^_CHEEVOS_HMAC_SECRET=.*|_CHEEVOS_HMAC_SECRET=\"${HMAC_SECRET}\"|" \
            "$ACHIEVEMENTS_DIR/scripts/lib.sh"
    else
        sed -i "s|^_CHEEVOS_HMAC_SECRET=.*|_CHEEVOS_HMAC_SECRET=\"${HMAC_SECRET}\"|" \
            "$ACHIEVEMENTS_DIR/scripts/lib.sh"
    fi
    echo "✓ HMAC secret injected into lib.sh"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Phase 1.6: Install /achievements and /uninstall-achievements slash commands
# ─────────────────────────────────────────────────────────────────────────────

COMMANDS_DIR="$HOME/.claude/commands"
mkdir -p "$COMMANDS_DIR"
cp "$REPO_DIR/commands/achievements.md" "$COMMANDS_DIR/achievements.md"
cp "$REPO_DIR/commands/uninstall-achievements.md" "$COMMANDS_DIR/uninstall-achievements.md"
echo "✓ /achievements and /uninstall-achievements slash commands installed to $COMMANDS_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 2: Merge hooks into settings.json (idempotent)
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

    if (.hooks.SessionStart // [] | map(.hooks // [] | map(.command) | any(. == $ss)) | any) then .
    else .hooks.SessionStart += [{"hooks": [{"type": "command", "command": $ss}]}]
    end |

    if (.hooks.PostToolUse // [] | map(.hooks // [] | map(.command) | any(. == $pt)) | any) then .
    else .hooks.PostToolUse += [{"hooks": [{"type": "command", "command": $pt, "async": true}]}]
    end |

    if (.hooks.Stop // [] | map(.hooks // [] | map(.command) | any(. == $st)) | any) then .
    else .hooks.Stop += [{"hooks": [{"type": "command", "command": $st}]}]
    end |

    if (.hooks.PreCompact // [] | map(.hooks // [] | map(.command) | any(. == $pc)) | any) then .
    else .hooks.PreCompact += [{"hooks": [{"type": "command", "command": $pc}]}]
    end
' "$SETTINGS" > "$TEMP"

if ! jq empty "$TEMP" 2>/dev/null; then
    rm -f "$TEMP"
    echo "ERROR: Failed to merge hooks - produced invalid JSON."
    exit 1
fi

mv "$TEMP" "$SETTINGS"
echo "✓ Hooks merged into settings.json"

# ─────────────────────────────────────────────────────────────────────────────
# Phase 3: Wrap statusLine command (points to binary now)
# ─────────────────────────────────────────────────────────────────────────────

WRAPPER_CMD="$ACHIEVEMENTS_DIR/cheevos statusline"
ORIGINAL_SAVE="$ACHIEVEMENTS_DIR/.original-statusline"

CURRENT_CMD=$(jq -r '.statusLine.command // ""' "$SETTINGS")
CURRENT_TYPE=$(jq -r '.statusLine.type // ""' "$SETTINGS")

if [[ "$CURRENT_CMD" == *"achievements/cheevos statusline"* ]] || \
   [[ "$CURRENT_CMD" == *"achievements/scripts/statusline-wrapper"* ]]; then
    # Already wrapped (either new or old style) — update to binary form
    TEMP=$(mktemp "$SETTINGS.XXXXXX")
    jq --arg cmd "$WRAPPER_CMD" '.statusLine.command = $cmd' "$SETTINGS" > "$TEMP" && mv "$TEMP" "$SETTINGS"
    echo "✓ statusLine updated to binary command"
elif [[ -z "$CURRENT_CMD" ]] || [[ "$CURRENT_TYPE" != "command" ]]; then
    printf '' > "$ORIGINAL_SAVE"
    TEMP=$(mktemp "$SETTINGS.XXXXXX")
    jq --arg cmd "$WRAPPER_CMD" '.statusLine = {"type": "command", "command": $cmd}' "$SETTINGS" > "$TEMP" && mv "$TEMP" "$SETTINGS"
    echo "✓ statusLine configured"
else
    printf '%s' "$CURRENT_CMD" > "$ORIGINAL_SAVE"
    TEMP=$(mktemp "$SETTINGS.XXXXXX")
    jq --arg cmd "$WRAPPER_CMD" '.statusLine.command = $cmd' "$SETTINGS" > "$TEMP" && mv "$TEMP" "$SETTINGS"
    echo "✓ statusLine wrapped (original saved to .original-statusline)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Phase 4: Validate final settings.json
# ─────────────────────────────────────────────────────────────────────────────

if ! jq empty "$SETTINGS" 2>/dev/null; then
    echo "ERROR: settings.json is invalid after install."
    exit 1
fi

# ─────────────────────────────────────────────────────────────────────────────
# Phase 5: Seed initial state (first install only) / migrate existing state
# ─────────────────────────────────────────────────────────────────────────────

# cheevos init creates .key and empty files if absent.
# cheevos seed pre-unlocks session achievements; it skips if state.json already exists.
# If state.json exists but is plaintext, cheevos update will migrate it automatically
# on first hook fire. No explicit migration step needed here.

if [[ ! -f "$ACHIEVEMENTS_DIR/state.json" ]]; then
    "$ACHIEVEMENTS_DIR/cheevos" seed "$HOME/.claude/stats-cache.json"
    echo "✓ Initial state seeded"
else
    echo "✓ Existing state preserved (upgrade — migration occurs on first hook fire if needed)"
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
echo "  State file: ENCRYPTED (AES-256-GCM)"
echo "  Definitions: embedded in binary (hidden)"
echo ""
echo "Restart Claude Code for hooks to take effect."
echo ""
echo "View your achievements:"
echo "  /achievements                              (slash command — opens web UI in browser)"
echo "  $ACHIEVEMENTS_DIR/cheevos serve           (web UI, run directly)"
echo "  $ACHIEVEMENTS_DIR/cheevos show            (static list)"
echo "  $ACHIEVEMENTS_DIR/cheevos learn           (tutorial path)"
echo ""
echo "Verify install:"
echo "  $ACHIEVEMENTS_DIR/cheevos verify"
echo ""
echo "Uninstall:"
echo "  /uninstall-achievements                    (slash command — interactive guided removal)"
echo "  $ACHIEVEMENTS_DIR/uninstall.sh             (run directly)"
