# Changelog

## [1.0.0] - 2026-03-12

### Added
- 18 achievements across sessions, file operations, shell usage, search, and MCP integrations
- Persistent score tracking in `~/.claude/achievements/state.json`
- Status bar integration via `statusline-wrapper.sh`
- Achievement unlock notifications via `Stop` hook `systemMessage` output
- Cross-platform file locking (`lockf` on macOS, `flock` on Linux)
- Atomic state writes via temp file + `mv`
- Retroactive session seeding from `~/.claude/stats-cache.json`
- Idempotent `install.sh` with upgrade detection
- `uninstall.sh` that restores original settings
- `async: true` on PostToolUse hook to avoid slowing Claude down
