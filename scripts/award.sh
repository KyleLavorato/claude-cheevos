#!/usr/bin/env bash
# award.sh - Thin shim; delegates to cheevos binary.
ACHIEVEMENTS_DIR="${ACHIEVEMENTS_DIR:-$HOME/.claude/achievements}"
exec "$ACHIEVEMENTS_DIR/cheevos" award "$@"
