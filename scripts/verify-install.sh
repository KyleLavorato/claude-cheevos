#!/usr/bin/env bash
# verify-install.sh - Verify Claude Cheevos installation
#
# Checks that all installed scripts have valid syntax and that the achievement
# system is properly configured in settings.json.
#
# Usage: bash verify-install.sh

set -euo pipefail

ACHIEVEMENTS_DIR="$HOME/.claude/achievements"
SETTINGS="$HOME/.claude/settings.json"

echo "Claude Cheevos Installation Verification"
echo "=========================================="
echo ""

# ─── Check installation directory ──────────────────────────────────────────────
if [[ ! -d "$ACHIEVEMENTS_DIR" ]]; then
    echo "✗ Installation directory not found: $ACHIEVEMENTS_DIR"
    echo "  Run 'bash install.sh' first."
    exit 1
fi

echo "✓ Installation directory exists"

# ─── Check required files ──────────────────────────────────────────────────────
REQUIRED_FILES=(
    "definitions.json"
    "state.json"
    "notifications.json"
    ".version"
    "hooks/session-start.sh"
    "hooks/post-tool-use.sh"
    "hooks/stop.sh"
    "hooks/pre-compact.sh"
    "scripts/lib.sh"
    "scripts/state-update.sh"
    "scripts/statusline-wrapper.sh"
    "scripts/show-achievements.sh"
    "scripts/learning-path.sh"
)

MISSING=0
for file in "${REQUIRED_FILES[@]}"; do
    if [[ ! -f "$ACHIEVEMENTS_DIR/$file" ]]; then
        echo "✗ Missing file: $file"
        MISSING=$((MISSING + 1))
    fi
done

if [[ $MISSING -gt 0 ]]; then
    echo ""
    echo "✗ $MISSING required file(s) missing - reinstall recommended"
    exit 1
fi

echo "✓ All required files present"

# ─── Validate JSON files ───────────────────────────────────────────────────────
for json_file in "definitions.json" "state.json" "notifications.json"; do
    if ! jq empty "$ACHIEVEMENTS_DIR/$json_file" 2>/dev/null; then
        echo "✗ Invalid JSON: $json_file"
        exit 1
    fi
done

echo "✓ All JSON files valid"

# ─── Validate shell script syntax ──────────────────────────────────────────────
SYNTAX_ERRORS=0
for script in "$ACHIEVEMENTS_DIR"/hooks/*.sh "$ACHIEVEMENTS_DIR"/scripts/*.sh; do
    if [[ -f "$script" ]]; then
        if ! bash -n "$script" 2>/dev/null; then
            echo "✗ Syntax error in $(basename "$script")"
            SYNTAX_ERRORS=$((SYNTAX_ERRORS + 1))
        fi
    fi
done

if [[ $SYNTAX_ERRORS -gt 0 ]]; then
    echo ""
    echo "✗ $SYNTAX_ERRORS script(s) have syntax errors - reinstall recommended"
    exit 1
fi

echo "✓ All scripts have valid syntax"

# ─── Check settings.json hooks ─────────────────────────────────────────────────
if [[ ! -f "$SETTINGS" ]]; then
    echo "✗ Claude Code settings.json not found: $SETTINGS"
    exit 1
fi

if ! jq empty "$SETTINGS" 2>/dev/null; then
    echo "✗ Invalid JSON in settings.json"
    exit 1
fi

HOOKS_REGISTERED=0
for hook_name in SessionStart PostToolUse Stop PreCompact; do
    if jq -e --arg h "$hook_name" '.hooks[$h] // [] | length > 0' "$SETTINGS" >/dev/null 2>&1; then
        HOOKS_REGISTERED=$((HOOKS_REGISTERED + 1))
    else
        echo "⚠  Hook not registered: $hook_name"
    fi
done

if [[ $HOOKS_REGISTERED -lt 4 ]]; then
    echo "✗ Only $HOOKS_REGISTERED/4 hooks registered - reinstall may be needed"
    exit 1
fi

echo "✓ All hooks registered in settings.json"

# ─── Check statusLine wrapper ──────────────────────────────────────────────────
STATUSLINE_CMD=$(jq -r '.statusLine.command // ""' "$SETTINGS")
if [[ "$STATUSLINE_CMD" == *"achievements/scripts/statusline-wrapper"* ]]; then
    echo "✓ Status line wrapper configured"
else
    echo "⚠  Status line wrapper not detected - score won't display in status bar"
fi

# ─── Show current stats ────────────────────────────────────────────────────────
echo ""
echo "Current Achievement Stats:"
echo "  Score:        $(jq -r '.score' "$ACHIEVEMENTS_DIR/state.json") pts"
echo "  Unlocked:     $(jq -r '.unlocked | length' "$ACHIEVEMENTS_DIR/state.json")/$(jq -r '.achievements | length' "$ACHIEVEMENTS_DIR/definitions.json")"
echo "  Version:      $(cat "$ACHIEVEMENTS_DIR/.version")"
echo ""
echo "✓ Installation verified successfully!"
echo ""
echo "View achievements: bash $ACHIEVEMENTS_DIR/scripts/show-achievements.sh"
echo "Tutorial path:     bash $ACHIEVEMENTS_DIR/scripts/learning-path.sh"
