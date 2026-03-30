# claude-cheevos - Claude Code Achievement System

![](docs/banner.png)

A self-contained achievement system for [Claude Code](https://claude.ai/code) that tracks your
usage milestones, awards points, and surfaces progress through three UIs and a live status bar.

---

## Requirements

- [Claude Code](https://claude.ai/code) installed (`~/.claude/settings.json` must exist)
- `bash` 3.2+ and `jq` 1.6+
- macOS, Linux, or Windows (via WSL)
- No other runtime dependencies — the core engine is a pre-built Go binary

---

## Installation

```bash
git clone https://github.com/KyleLavorato/claude-cheevos.git
cd claude-cheevos
bash install.sh

# Optional: enable leaderboard sync (pushes your score on every achievement unlock)
bash install.sh --token <api-token> --api-url https://...execute-api.../prod

# Optional: join a team for collaborative achievements
bash install.sh --token <token> --api-url <url> --team-id <team-uuid> --team-name "Team Name"
```

The installer is **idempotent** — safe to run again to upgrade scripts. Your score and progress
are never touched on reinstall. If `--token`/`--api-url` are omitted, leaderboard sync is
disabled and everything else works normally.

**Auto-updates are enabled by default** — new achievements will be automatically downloaded from
the public GitHub repo once per day. See the [Auto-Updates](#auto-updates) section for details.

The web UI (`cheevos serve`) is built into the main binary — no separate Go installation required
to use it. Go is only needed if you are building the binary from source.

Then **restart Claude Code** for hooks to take effect.

### What gets installed

Everything is copied to `~/.claude/achievements/` so the repo can be deleted after install.

```
~/.claude/achievements/
├── cheevos                   # Pre-built Go binary — contains all achievement logic
├── .key                      # Per-installation AES-256 encryption key (chmod 600)
├── state.json                # Encrypted state (score, counters, unlocked list)
├── notifications.json        # Pending unlock queue ([] when empty)
├── state.lock                # Lock file (do not delete)
├── leaderboard.conf          # Leaderboard config: enabled, UUID, token, API URL (chmod 600)
├── .version                  # Installed version
├── .original-statusline      # Your previous statusLine command (restored on uninstall)
├── .last-update-check        # Timestamp of last auto-update check (unix epoch seconds)
├── uninstall.sh              # Copy of uninstall.sh (used by the /uninstall-achievements command)
├── hooks/
│   ├── session-start.sh      # Fires on session start/resume
│   ├── post-tool-use.sh      # Fires after every tool call (async)
│   ├── pre-compact.sh        # Fires before context compaction
│   └── stop.sh               # Fires at end of every assistant turn
├── scripts/
│   ├── lib.sh                 # Shared paths and HMAC helpers
│   ├── statusline-wrapper.sh  # Thin shim → cheevos statusline
│   ├── seed-state.sh          # Thin shim → cheevos seed
│   ├── show-achievements.sh   # Thin shim → cheevos show
│   ├── learning-path.sh       # Thin shim → cheevos learn
│   ├── tui.sh                 # Interactive terminal TUI (arrow-key navigation)
│   ├── award.sh               # Thin shim → cheevos award
│   └── verify-install.sh      # Thin shim → cheevos verify
└── logs/
    └── leaderboard.log        # Append-only sync log (HTTP status per PUT, token never logged)
```

> **State is encrypted.** `state.json` is AES-256-GCM encrypted — `jq` will not reveal your
> score or counters. Use `cheevos show` to read your state.

Slash commands are also installed to `~/.claude/commands/`:

```
~/.claude/commands/
├── achievements.md            # /achievements — opens web UI in browser
└── uninstall-achievements.md  # /uninstall-achievements — interactive uninstall flow
```

### Uninstallation

```bash
bash uninstall.sh
```

Restores your original `statusLine`, removes all four hooks from `settings.json`, and
optionally deletes `~/.claude/achievements/`.

You can also uninstall from inside Claude Code using the `/uninstall-achievements` slash
command — it walks you through the same steps with a confirmation dialog.

### Verifying after install

```bash
~/.claude/achievements/cheevos verify
```

This checks the binary, encryption key, encrypted state, notifications file, hook
registrations in `settings.json`, and statusLine configuration.

---

## Status Bar

After install, your Claude Code status bar shows your current score at all times:

```
🏆 560 pts
```

If you had an existing `statusLine` command before install, it still runs — cheevos wraps
it and appends the score.

---

## Slash Commands

Two slash commands are installed to `~/.claude/commands/` and are immediately available
inside Claude Code after installation (no restart required for the commands themselves,
though the hooks do require a restart).

### `/achievements`

Opens the achievement browser web UI in your default browser using `cheevos serve`.

### `/uninstall-achievements`

Runs an interactive uninstall flow entirely inside Claude Code:

1. Checks whether you are registered on the leaderboard
2. Shows a confirmation dialog (with a leaderboard warning if applicable) and a "heads up"
   about needing to restart Claude Code
3. Runs `uninstall.sh` with the appropriate flags based on your selection (keep data vs.
   delete everything)

---

## UI 1 — Achievement List (`cheevos show`)

Browse your full achievement list with filters.

```bash
~/.claude/achievements/cheevos show
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
cheevos show --locked --beginner     # What beginner stuff is left?
cheevos show --unlocked              # Victory lap
cheevos show --locked --intermediate # Next targets
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

## UI 2 — Tutorial (`cheevos learn`)

A guided walkthrough of the core beginner achievements, with tips, a progress bar, and
an "Up Next" section showing your next three targets.

```bash
~/.claude/achievements/cheevos learn
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

## UI 3 — Web UI (`cheevos serve`)

An interactive achievement browser that runs as a local HTTP server and opens in your
default browser automatically.

**Run:**

```bash
~/.claude/achievements/cheevos serve
# or from inside Claude Code:
# /achievements
```

**Features:**

- Dark theme using Claude Code's colour scheme (warm dark backgrounds, orange `#cc785c` accent)
- Filter by status: All / Unlocked / Locked
- Filter by skill level: All / Beginner / Intermediate / Experienced / Master / Secret
- Search by name or description
- Displays your score vs. total possible (e.g. `665 / 5600 pts`)
- Progress bars for locked achievements showing `current / threshold`
- "Done" button or Ctrl-C to stop the server
- Listens on a random available localhost port (printed on startup)

---

## UI 4 — Terminal TUI (`tui.sh`)

A pure-bash interactive terminal UI with arrow-key navigation — useful when a browser is not
available or you prefer to stay in the terminal.

**Run:**

```bash
bash ~/.claude/achievements/scripts/tui.sh
```

**Navigation:**

| Key | Action |
|---|---|
| Arrow Up / `k` | Move selection up |
| Arrow Down / `j` | Move selection down |
| Enter | Open detail view for selected achievement |
| Esc | Return from detail view to list |
| `q` | Quit |

**Features:**

- Alternate-screen buffer (your terminal is restored on exit)
- Category-grouped scrollable list
- Colour-coded status icons for unlocked / in-progress / locked / secret achievements
- Detail view shows description, skill level, progress bar, and unlock date (if applicable)
- No external dependencies beyond `jq` and `tput`

---

## 👥 Team Achievements

Join a team to unlock collaborative achievements and compete on team leaderboards!

**Quick start:**
```bash
bash install.sh \
  --token <token> \
  --api-url <url> \
  --team-id <team-uuid> \
  --team-name "Squad Jackal"
```

**View your team progress:**
```bash
~/.claude/achievements/cheevos team-stats
```

**Team achievement types:**

1. **Collaborative** — Every team member must reach the goal individually
   - *Example:* "Squad Goals" — All members hit 100 sessions (+500 pts)

2. **Aggregate** — Team totals are summed across all members
   - *Example:* "Knowledge Share" — Team reads 10,000 files collectively (+750 pts)
   - *Example:* "Code Factory" — Team writes 5,000 files together (+600 pts)

3. **Competitive** — Based on leaderboard rank
   - *Example:* "Top Squad" — #1 team for 7 consecutive days (+2000 pts, secret)

**How it works:**
- Your team ID is stored in `~/.claude/achievements/leaderboard.conf`
- Individual stats are synced to the leaderboard API with your team_id
- Local `team-stats` command shows your contribution (no backend required)
- Backend aggregation and team leaderboards coming soon

**Current status:** Client-side ready. Team IDs are sent to the leaderboard API, but backend aggregation is pending. See [TEAMS.md](TEAMS.md) for full documentation, technical details, and roadmap.

---

## Achievement Categories

There are **136+ achievements** across 15 categories:

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
| **Team** | Collaborative achievements for teams (see [TEAMS.md](TEAMS.md)) |

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
1. On session startup, `session-start.sh` triggers `cheevos update-defs` in the background
2. The binary checks for new achievement IDs in the remote `definitions.json`
3. New achievements are merged into a local override file (existing ones are never modified)
4. You get a desktop notification when new achievements are added
5. Your progress and unlocked achievements are always preserved

**Rate limiting:** Update checks only run once per 24 hours to avoid GitHub API rate limits.

**Manual check:**
```bash
~/.claude/achievements/cheevos update-defs --force
```

**Disabling auto-updates:** Remove the `cheevos update-defs &` line from
`~/.claude/achievements/hooks/session-start.sh`. You can still manually trigger
updates with `--force`.

See [`AUTO_UPDATE.md`](AUTO_UPDATE.md) for full details.

---

## Easter Eggs

Some achievements can't be tracked automatically and require deliberately asking Claude.

**Hey Unlock This** — ask Claude to unlock it. Claude will run:
```bash
~/.claude/achievements/cheevos award easter_egg_unlocks
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

Edit `data/definitions.json` in the repo, rebuild the binary (`cd go && make dist`), and re-run `install.sh`. Your progress is preserved.

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

### 3. Cheevos sync (`cheevos leaderboard-sync`)

Installed automatically with `--token` and `--api-url`. After every assistant turn,
`stop.sh` calls `cheevos leaderboard-sync` in the background. It does a silent
`PUT /users/{uuid}` with the current score — the token is never written to logs.

```bash
# Verify your leaderboard config after install
cat ~/.claude/achievements/leaderboard.conf
tail -f ~/.claude/achievements/logs/leaderboard.log
```

**Note:** A macOS bug where `head -n -1` (GNU-only behaviour) caused `leaderboard-sync.sh`
to exit before logging successful API calls has been fixed. The script now uses `sed '$d'`
instead, which is portable across macOS and Linux.

---

## TODO

- [ ] Add tamper protection to `state.json` (e.g. HMAC signature) to prevent manually editing counters to cheat achievements
- [x] ~~Protect the `award.sh` script so it can only be called for valid achievement counters~~ — `award.sh` now validates the counter name against `definitions.json`
- [x] Auto-update — have Claude check the public GitHub repo for new `definitions.json` entries and pull them down automatically when new achievements are published
- [ ] Dev mode — a flag or env var that bypasses tamper protection and lets you manually unlock any achievement by ID for testing purposes (e.g. `CHEEVOS_DEV=1 bash award.sh <achievement_id>`)
- [ ] In dev mode, permanently flag `state.json` so the account is ineligible for leaderboard submission — dev-mode unlocks should never count toward any public rankings
