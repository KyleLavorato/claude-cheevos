# How Achievements Are Tracked

## Hooks

Four Claude Code hooks fire automatically as you work:

| Hook | Event | Mode | Tracks |
|---|---|---|---|
| `session-start.sh` | `SessionStart` | Sync | New sessions, session resumes, streak, concurrent sessions, time-of-day events, `--dangerously-skip-permissions` flag. Also triggers auto-update check (background) |
| `post-tool-use.sh` | `PostToolUse` | **Async** | Every tool call — file writes, bash commands, searches, MCP calls, skills, tasks, plan mode exits |
| `pre-compact.sh` | `PreCompact` | Sync | Auto-compacts vs manual compacts, 1M-token context fills |
| `stop.sh` | `Stop` | Sync | Model tracking, transcript phrase detection, code review quality, token accumulation, notification display |

## What triggers what

**Writing files** — the Write tool inspects the file path and content for:
- API spec files (`openapi.*`, `swagger.*`, `asyncapi.*`, or files in `/spec/` dirs)
- Custom slash commands (`.claude/commands/*.md`)
- `CLAUDE.md` files
- Test files (`*.test.ts`, `*_test.go`, `test_*.py`, etc.)
- `README*` files

**Bash commands** — the command string is checked for:
- `git commit`, `git push --force`, `git revert`, `kill -9`, `sudo`
- Test runners: `pytest`, `npm test`, `go test`, `cargo test`, `rspec`, etc.
- `gh pr create`

**Skills** — any skill whose name contains "review" counts as a code review

**Transcript analysis** (end of every turn) — the last assistant message is scanned for:
- "sorry" → `apologies`
- "great question" → `great_question_said`
- "sorry, dave" → `hal_9000_said`
- Output tokens = 777 → `lucky_sessions`
- Code review quality signals (LGTM / 10+ numbered issues)
