# claude-cheevos - Claude Code Achievement System

![](docs/banner.png)

A self-contained achievement system for [Claude Code](https://claude.ai/code) that tracks your
usage milestones, awards points, and surfaces progress through three UIs and a live status bar.

---

## Requirements

- [Claude Code](https://claude.ai/code) installed (`~/.claude/settings.json` must exist)
- `bash` 3.2+ (macOS default is fine — but see [Bash 3.2 constraints](#bash-32-constraints-macos) below)
- `jq` 1.6+
- macOS or Linux (Windows via WSL)

---

## Installation

```bash
git clone https://github.com/KyleLavorato/claude-cheevos.git
cd claude-cheevos
bash install.sh

# Optional: enable leaderboard sync (pushes your score on every achievement unlock)
bash install.sh --token <api-token> --api-url https://...execute-api.../prod
```

The installer is **idempotent** — safe to run again to upgrade scripts. Your score and progress
are never touched on reinstall. If `--token`/`--api-url` are omitted, leaderboard sync is
disabled and everything else works normally.

**Auto-updates are enabled by default** — new achievements will be automatically downloaded from
the public GitHub repo once per day. See the [Auto-Updates](#auto-updates) section for details.

Then **restart Claude Code** for hooks to take effect.

### What gets installed

Everything is copied to `~/.claude/achievements/` so the repo can be deleted after install.

```
~/.claude/achievements/
├── definitions.json          # All achievement definitions
├── state.json                # Your score, counters, unlocked list
├── notifications.json        # Pending unlock queue ([] when empty)
├── state.lock                # Lock file (do not delete)
├── leaderboard.conf          # Leaderboard config: enabled, UUID, token, API URL (chmod 600)
├── .version                  # Installed version
├── .original-statusline      # Your previous statusLine command (restored on uninstall)
├── hooks/
│   ├── session-start.sh      # Fires on session start/resume
│   ├── post-tool-use.sh      # Fires after every tool call (async)
│   ├── pre-compact.sh        # Fires before context compaction
│   └── stop.sh               # Fires at end of every assistant turn
├── scripts/
│   ├── lib.sh                 # Shared paths and locking
│   ├── state-update.sh        # Atomic state writer (always called under lock)
│   ├── statusline-wrapper.sh  # Status bar output
│   ├── seed-state.sh          # First-install state seeder
│   ├── show-achievements.sh   # Full achievement list UI
│   ├── learning-path.sh       # Guided tutorial UI
│   ├── award.sh               # Manual Easter egg award tool
│   ├── check-updates.sh       # Auto-update definitions from GitHub (runs once/day)
│   └── leaderboard-sync.sh    # Score push to leaderboard API (fire-and-forget)
└── logs/
    └── leaderboard.log        # Append-only sync log (HTTP status per PUT, token never logged)
```

### Uninstallation

```bash
bash uninstall.sh
```

Restores your original `statusLine`, removes all four hooks from `settings.json`, and
optionally deletes `~/.claude/achievements/`.

### Verifying after install

Run the verification script to check your installation:

```bash
bash ~/.claude/achievements/scripts/verify-install.sh
```

This validates all scripts, JSON files, hooks, and displays your current stats.

Alternatively, manually check each script's syntax:

```bash
for f in ~/.claude/achievements/hooks/*.sh ~/.claude/achievements/scripts/*.sh; do
    bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"
done
```

All scripts should report `OK`. If any report `FAIL`, see
[Bash 3.2 constraints](#bash-32-constraints-macos) below for common causes.

---

## Status Bar

After install, your Claude Code status bar shows your current score at all times:

```
🏆 560 pts
```

For **5 minutes after unlocking** an achievement, the name is shown:

```
🏆 710 pts (Power User!)
```

If you had an existing `statusLine` command before install, it still runs — cheevos wraps
it and appends the score.

---

## UI 1 — Achievement List (`show-achievements.sh`)

Browse your full achievement list with filters.

```bash
bash ~/.claude/achievements/scripts/show-achievements.sh
```

**Interactive mode** (when run in a terminal with no flags): shows two prompts —
unlock status first, then skill level.

**CLI flags** (combinable):

```bash
# Unlock status
-a / --all          All achievements (default)
-u / --unlocked     Unlocked only
-l / --locked       Locked only

# Skill level
-B / --beginner
-I / --intermediate
-E / --experienced
-M / --master
-S / --secret

# Examples
bash show-achievements.sh --locked --beginner     # What beginner stuff is left?
bash show-achievements.sh --unlocked              # Victory lap
bash show-achievements.sh --locked --intermediate # Next targets
```

**What you'll see:**

```
🏆  Claude Cheevos  (locked · beginner)
Score: 315 pts  ·  12/85 unlocked

Sessions
  ✅  Hello, World              +10 pts   Start your first Claude Code session  · 2026-03-23
  🔒  Frequent Flier            +25 pts   Complete 10 sessions  [3/10]

Files
  ✅  Code Sculptor             +20 pts   Write 10 files with Claude  · 2026-03-23
  🔒  Prolific Author           +100 pts  Write 100 files  [23/100]
```

- ✅ green = unlocked, with the unlock date shown in dim text
- 🔒 with `[current/threshold]` = locked, shows your progress
- 🔮 `???` = secret achievement, description hidden until unlocked

---

## UI 2 — Tutorial (`learning-path.sh`)

A guided walkthrough of the core beginner achievements, with tips, a progress bar, and
an "Up Next" section showing your next three targets.

```bash
bash ~/.claude/achievements/scripts/learning-path.sh
```

**Example output:**

```
🗺️   Claude Cheevos — Tutorial
3/8 complete  ·  [████████░░░░░░░░░░░░]  60/165 pts

⭐  Up Next
────────────────────────────────────────────────────────────
  ⭐  Code Sculptor              +20 pts  [3/10 files_written]
      Write 10 files with Claude
      💡 Ask Claude to create files: 'Create a utils.py with a helper function'

  ⭐  Bookworm                   +50 pts  [12/100 files_read]
      Read 100 files with Claude
      💡 Ask Claude to read and analyze code: 'Explain what this file does'

Full Path
────────────────────────────────────────────────────────────
  ✅   1. Hello, World           +10 pts  Start your first Claude Code session
  ✅   2. Back Again             +15 pts  Resume a previous Claude session
  ✅   3. Curious Mind           +10 pts  Perform your first web search via Claude
  ⭐   4. Code Sculptor          +20 pts  [3/10]
  ⭐   5. Bookworm               +50 pts  [12/100]
  ⭐   6. Laying Down the Law    +15 pts  [0/1]
  🔒   7. Shell Jockey           +30 pts  [0/50]
  🔒   8. Think First            +15 pts  [0/1]
```

The tutorial set is configured via `"tutorial": true` in `definitions.json` — no script changes
needed to add or remove achievements from it.

**Current tutorial set** (8 achievements, 165 pts):

| # | Achievement | Tip |
|---|---|---|
| 1 | Hello, World | Just run `claude` |
| 2 | Code Sculptor | Ask Claude to create some files |
| 3 | Bookworm | Ask Claude to read and explain source files |
| 4 | Shell Jockey | Ask Claude to run shell commands |
| 5 | Curious Mind | Ask a question needing current info |
| 6 | Think First | Ask Claude to plan before implementing |
| 7 | Back Again | Run `claude --resume` or type `/resume` |
| 8 | Laying Down the Law | Ask Claude to create a `CLAUDE.md` |

Completing all 8 tutorial achievements unlocks the **Graduate** rank badge.

---

## Achievement Categories

There are **85+ achievements** across 12 categories:

| Category | Description |
|---|---|
| **Sessions** | Starting and completing Claude Code sessions |
| **Files** | Writing and reading files through Claude |
| **Shell** | Running bash commands through Claude |
| **Search** | Web searches and glob/grep searches |
| **MCP Integrations** | GitHub, Jira/Confluence, and other MCP tool calls |
| **Plan Mode** | Using Claude's plan mode workflow |
| **Token Consumption** | Total tokens consumed across sessions |
| **Commands & Skills** | Invoking skills and creating custom slash commands |
| **Context & Compaction** | Filling and compacting the context window |
| **API Specs** | Writing OpenAPI, Swagger, and AsyncAPI spec files |
| **Code Reviews** | Running code reviews and their quality outcomes |
| **Testing** | Writing test files and running test suites |
| **Miscellaneous** | One-off events, Easter eggs, and fun milestones |
| **Rank** | Meta-achievements for completing sets of other achievements |

### Skill levels

Every achievement has a level: **Beginner → Intermediate → Experienced → Master → Impossible**

There is also a **Secret** tier. Secret achievements show as `🔮 ???` in the UI until unlocked — you can see they exist and their point value, but not what you need to do to earn them. Run `show-achievements.sh --secret` (or `-S`) to list only secret achievements.

Rank achievements form a progression chain:
**Graduate** → **Graduation Day** → **Middle Management** → **Elite Operator** → **Efficiency Grandmaster** → **Beyond the Claudeverse**

---

## How Achievements Are Tracked

### Hooks

Four Claude Code hooks fire automatically as you work:

| Hook | Event | Mode | Tracks |
|---|---|---|---|
| `session-start.sh` | `SessionStart` | Sync | New sessions, session resumes, streak, concurrent sessions, time-of-day events, `--dangerously-skip-permissions` flag. Also triggers auto-update check (background) |
| `post-tool-use.sh` | `PostToolUse` | **Async** | Every tool call — file writes, bash commands, searches, MCP calls, skills, tasks, plan mode exits |
| `pre-compact.sh` | `PreCompact` | Sync | Auto-compacts vs manual compacts, 1M-token context fills |
| `stop.sh` | `Stop` | Sync | Model tracking, transcript phrase detection, code review quality, token accumulation, notification display |

### What triggers what

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

---

## Notifications

When an achievement unlocks you get:

1. **Inline system message** — displayed inside Claude Code at the end of the turn:
   ```
   🏆 Achievement Unlocked!
     [Power User +150 pts] Complete 100 Claude Code sessions
   Total Score: 710 pts
   ```

2. **Desktop notification** — native OS notification:
   - **macOS** — native notification with Glass sound via `osascript`
   - **WSL/Windows** — Windows Toast notification via PowerShell

Multiple unlocks in the same turn are batched into one notification.

---

## Auto-Updates

New achievements are automatically downloaded from the public GitHub repo once per day when you start a new Claude Code session.

**How it works:**
1. On session startup, `session-start.sh` triggers `check-updates.sh` in the background
2. The script checks for new achievement IDs in the remote `definitions.json`
3. New achievements are merged into your local definitions (existing ones are never modified)
4. You get a desktop notification when new achievements are added
5. Your progress and unlocked achievements are always preserved

**Rate limiting:** Update checks only run once per 24 hours to avoid GitHub API rate limits.

**Manual check:**
```bash
bash ~/.claude/achievements/scripts/check-updates.sh --force
```

**Configuration:** The update system fetches from `KyleLavorato/claude-cheevos/main/data/definitions.json`. To change the source repo or branch, edit `GITHUB_REPO` and `GITHUB_BRANCH` in `~/.claude/achievements/scripts/check-updates.sh`.

**Disabling auto-updates:** Remove the auto-update trigger from `~/.claude/achievements/hooks/session-start.sh` (look for the `check-updates.sh &` line). You can still manually trigger updates with `--force`.

See [`AUTO_UPDATE.md`](AUTO_UPDATE.md) for full details.

---

## Easter Eggs

Some achievements can't be tracked automatically and require deliberately asking Claude.

**Hey Unlock This** — ask Claude to unlock it. Claude will run:
```bash
bash ~/.claude/achievements/scripts/award.sh easter_egg_unlocks
```

> **Note:** `award.sh` validates the counter name against `definitions.json` — only counters
> that are referenced by at least one achievement are accepted. Arbitrary or misspelled counter
> names are rejected with an error.

Other fun ones to try:
- **Execute Order 66** — ask Claude to `kill -9` a process
- **I am groot, wait I mean root** — ask Claude to run a `sudo` command
- **Rewriting History** — ask Claude to `git push --force`
- **I'm Sorry, Dave** — ask Claude to respond with the HAL 9000 phrase
- **Lucky 7s** — engineer a response that uses exactly 777 output tokens

---

## Adding Custom Achievements

Edit `data/definitions.json` in the repo and re-run `install.sh`. Your progress is preserved.

```json
{
    "id": "my_achievement",
    "name": "Display Name",
    "description": "What the user did",
    "points": 20,
    "category": "misc",
    "skill_level": "beginner",
    "condition": { "counter": "my_counter", "threshold": 1 },
    "tutorial": true
}
```

Add `"tutorial": true` to include it in the learning path UI.

For the full list of available counters, condition types, and hook extension patterns,
see [`CLAUDE.md`](CLAUDE.md).

---

## Bash 3.2 Constraints (macOS)

macOS ships with Bash 3.2 due to GPLv3 licensing. All scripts in this project must
be compatible with Bash 3.2. Key restrictions:

| Feature | Bash 4+ only | Bash 3.2 alternative |
|---|---|---|
| `declare -A` (associative arrays) | Yes | `case` statements, TSV variables with `grep`+`cut`, or newline-delimited strings with `grep -qx` |
| `${var^^}` (uppercase) | Yes | `echo "$var" \| tr '[:lower:]' '[:upper:]'` or `grep -qi` |
| `mapfile` / `readarray` | Yes | `while IFS= read -r line; do ... done < <(...)` |
| Single quotes inside `'...'` jq strings | N/A (bash limitation in all versions) | Use `.` or `.?` in regex instead of literal `'` (e.g. `you.?re` not `you'?re`) |

**Quoting pitfall:** The jq expressions in `stop.sh` are wrapped in single quotes
spanning 60+ lines. A single stray `'` inside that block (e.g. in a regex pattern)
silently breaks the quoting — bash reports `unexpected EOF` at the *end* of the file,
not at the offending line. Always run `bash -n script.sh` after editing.

**Troubleshooting:** If you see `declare: -A: invalid option` errors, ensure you are
running the scripts with `bash` explicitly (not `sh`). All scripts include `#!/usr/bin/env bash`
shebang lines and are designed to be Bash 3.2 compatible. Running them with `/bin/sh` will fail
on macOS, as `/bin/sh` may map to a different shell. Always invoke: `bash script.sh`

---

## Leaderboard

An optional live leaderboard lets you compare scores with teammates. It consists of three
parts deployed separately:

### 1. AWS microservice (`microservice/`)

A self-contained CloudFormation stack: API Gateway → Lambda → DynamoDB, secured by an
auto-generated Secrets Manager bearer token (no token to invent or store beforehand).

```bash
cd microservice
aws cloudformation deploy \
  --template-file template.yaml \
  --stack-name service-claude-cheevo \
  --parameter-overrides Environment=prod \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Retrieve the generated token and API URL
TOKEN=$(aws secretsmanager get-secret-value \
  --secret-id service-claude-cheevo/api-token --query SecretString --output text)
API_URL=$(aws cloudformation describe-stacks --stack-name service-claude-cheevo \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiUrl`].OutputValue' --output text)
```

See `microservice/README.md` for the full API reference.

### 2. GitHub Pages UI (`leaderboard-ui/`)

A generic dark-theme leaderboard (sortable by score, top-3 medal highlights, 30s auto-refresh).
Copy `leaderboard-ui/docs/` to any GitHub repo, fill in `API_URL` and `API_TOKEN` in `app.js`,
enable GitHub Pages from `main → /docs`, and it's live.

See `leaderboard-ui/README.md` for step-by-step setup.

### 3. Cheevos sync (`leaderboard-sync.sh`)

Installed automatically with `--token` and `--api-url`. After every achievement unlock,
`stop.sh` calls `leaderboard-sync.sh` in the background. It does a silent `PUT /users/{uuid}`
with the current score — the token is never written to logs.

```bash
# Verify your leaderboard config after install
cat ~/.claude/achievements/leaderboard.conf
tail -f ~/.claude/achievements/logs/leaderboard.log
```

---

## TODO

- [ ] Add tamper protection to `state.json` (e.g. HMAC signature) to prevent manually editing counters to cheat achievements
- [x] ~~Protect the `award.sh` script so it can only be called for valid achievement counters~~ — `award.sh` now validates the counter name against `definitions.json`
- [x] Auto-update — have Claude check the public GitHub repo for new `definitions.json` entries and pull them down automatically when new achievements are published
- [ ] Dev mode — a flag or env var that bypasses tamper protection and lets you manually unlock any achievement by ID for testing purposes (e.g. `CHEEVOS_DEV=1 bash award.sh <achievement_id>`)
- [ ] Encrypt `state.json` so achievement progress cannot be read or modified in plaintext — prevents cheating without requiring a full HMAC signature scheme
- [ ] In dev mode, permanently flag `state.json` so the account is ineligible for leaderboard submission — dev-mode unlocks should never count toward any public rankings
