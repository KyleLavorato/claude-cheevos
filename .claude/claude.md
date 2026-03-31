# cheevos — Claude Code Achievement System

A self-contained achievement system for Claude Code that tracks usage milestones via hooks,
awards points, and displays the score in the status bar. Installed to `~/.claude/achievements/`.

The core engine is a compiled Go binary (`cheevos`) that stores state in an AES-256-GCM
encrypted file, embeds achievement definitions at compile time, and validates hook calls
with HMAC-SHA256 signatures to prevent casual tampering.

## Project Layout

```
cheevos/
├── data/definitions.json        # All achievement definitions (source of truth for embed)
├── hooks/
│   ├── session-start.sh         # SessionStart hook — sessions, streak, time-based, concurrent
│   ├── post-tool-use.sh         # PostToolUse hook (async) — all tool-use counter tracking
│   ├── pre-compact.sh           # PreCompact hook — auto-compact and manual compact tracking
│   └── stop.sh                  # Stop hook — transcript analysis + drain + leaderboard sync
├── scripts/
│   ├── lib.sh                   # Shared library: paths, HMAC helpers, _CHEEVOS_HMAC_SECRET
│   ├── statusline-wrapper.sh    # Thin shim → cheevos statusline
│   ├── seed-state.sh            # Thin shim → cheevos seed
│   ├── show-achievements.sh     # Thin shim → cheevos show
│   ├── award.sh                 # Thin shim → cheevos award
│   └── verify-install.sh        # Thin shim → cheevos verify
├── commands/
│   ├── achievements.md          # /achievements slash command — runs cheevos serve, opens browser
│   ├── get-started.md           # /get-started slash command — interactive guided tour
│   └── uninstall-achievements.md # /uninstall-achievements slash command — interactive uninstall
├── go/                          # Go source for the cheevos binary
│   ├── go.mod / go.sum
│   ├── Makefile                 # cross-compile matrix (requires CHEEVOS_HMAC_KEY env var)
│   ├── cmd/cheevos/             # CLI entrypoint + subcommand handlers
│   │   └── subcmd/serve.go      # (to be added) — achievement browser web UI
│   ├── internal/
│   │   ├── store/               # EncryptedJSONStore (AES-256-GCM), StateStore interface
│   │   ├── crypto/              # AES helpers, key loading, HMAC key deobfuscation
│   │   ├── engine/              # Achievement-checking engine (port of state-update.sh)
│   │   ├── defs/                # Embedded definitions + on-disk override loader
│   │   ├── hmac/                # HMAC-SHA256 payload verification
│   │   ├── lock/                # Cross-platform advisory file lock
│   │   └── notify/              # OS notification dispatch (macOS/Linux/Windows)
│   └── tools/keygen/            # 3-mode tool: HMAC key gen, leaderboard secret gen, or both
├── .github/workflows/
│   ├── publish.yml              # workflow_dispatch — build all platforms, publish release
│   ├── cicd.yml                 # pull_request — run tests + build all platforms
│   └── generate-leaderboard-secret.yml  # workflow_dispatch — encrypt leaderboard credentials
├── dist/                        # Per-platform release zips (produced by `make dist-zip`)
│   ├── claude-cheevos-darwin-amd64.zip
│   ├── claude-cheevos-darwin-arm64.zip
│   ├── claude-cheevos-linux-amd64.zip
│   ├── claude-cheevos-linux-arm64.zip
│   └── claude-cheevos-windows-amd64.zip
├── microservice/
│   ├── template.yaml            # Self-contained CloudFormation stack (all Lambda inline)
│   └── README.md                # Deploy, smoke test, API reference
├── leaderboard-ui/
│   ├── docs/                    # Generic GitHub Pages UI (index.html, style.css, app.js)
│   └── README.md                # Setup guide for generic deployment
├── install.sh                   # Idempotent installer — installs binary + scripts + hooks
├── uninstall.sh                 # Removes hooks from settings.json, optionally deletes state
└── README.md
```

Installed runtime lives at `~/.claude/achievements/` (state never touched on reinstall).

## Runtime Files (installed to `~/.claude/achievements/`)

| File | Purpose |
|---|---|
| `cheevos` | The compiled binary — all state logic lives here |
| `state.json` | AES-256-GCM encrypted state (score, counters, unlocked list, models_used) |
| `definitions.json` | On-disk definitions override (written by `cheevos update-defs`; absent = use embedded) |
| `notifications.json` | Queue of pending unlock notifications (`[]` when empty) |
| `state.lock` | Advisory lockfile (never delete manually) |
| `.version` | Installed version string — used by install.sh for upgrade detection |
| `.original-statusline` | Prior `statusLine.command` value saved for uninstall restoration |
| `hooks/`, `scripts/` | All scripts copied from repo (safe to overwrite on upgrade) |
| `uninstall.sh` | Copy of uninstall.sh — referenced by `/uninstall-achievements` slash command |
| `leaderboard.conf` | Leaderboard config: enabled flag, user UUID, encrypted secret (chmod 600) |
| `logs/leaderboard.log` | Append-only sync log — every PUT attempt logged (success and failure) |

Slash commands are installed to `~/.claude/commands/` (not inside `achievements/`):

| File | Purpose |
|---|---|
| `~/.claude/commands/achievements.md` | `/achievements` — runs `cheevos serve` in background, opens browser |
| `~/.claude/commands/get-started.md` | `/get-started` — interactive guided tour for new users (18 tutorial achievements) |
| `~/.claude/commands/uninstall-achievements.md` | `/uninstall-achievements` — interactive uninstall with leaderboard warning |

## Install and Test

```bash
# Build all platforms (cross-compile) + package per-platform zips
make dist-zip

# Install (end-user step, requires jq + bash only)
bash install.sh
bash uninstall.sh

# Leaderboard-enabled install (pass encrypted secret generated by keygen tool)
bash install.sh --leaderboard-secret <secret>

# View achievements (inside a Claude session — run 'claude' first):
/achievements                                                  # opens web UI in browser
/get-started                                                   # interactive guided tour (18 tutorial achievements)

# View achievements (from terminal):
~/.claude/achievements/cheevos serve                          # opens web UI in browser
~/.claude/achievements/cheevos show [--unlocked] [--beginner] # static list

# Uninstall (inside a Claude session):
/uninstall-achievements                                        # interactive, leaderboard-aware

# Award an Easter egg counter manually
~/.claude/achievements/cheevos award easter_egg_unlocks

# Verify installation
~/.claude/achievements/cheevos verify

# Force-check for new achievement definitions from GitHub
~/.claude/achievements/cheevos update-defs --force

# Verify leaderboard config (secret is encrypted, chmod 600)
cat ~/.claude/achievements/leaderboard.conf
tail -f ~/.claude/achievements/logs/leaderboard.log  # watch syncs live (all calls, not just failures)
```

After install, restart Claude Code for hooks to take effect.

### Manual Hook Testing

Hooks read JSON from stdin. Pipe a payload directly to test without running Claude:

```bash
DIR=~/.claude/achievements

# Test a bash command counter (bash_calls)
echo '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}' \
    | bash "$DIR/hooks/post-tool-use.sh"

# Read score (state is encrypted — use the binary, not jq directly)
$DIR/cheevos show --unlocked

# Test git commit detection
echo '{"tool_name":"Bash","tool_input":{"command":"git commit -m test"}}' \
    | bash "$DIR/hooks/post-tool-use.sh"

# Test a Write to CLAUDE.md
echo '{"tool_name":"Write","tool_input":{"file_path":"/tmp/CLAUDE.md","content":"hi"}}' \
    | bash "$DIR/hooks/post-tool-use.sh"

# Test session-start (startup source)
echo '{"source":"startup","session_id":"test","transcript_path":""}' \
    | bash "$DIR/hooks/session-start.sh"

# Test session resume
echo '{"source":"resume","session_id":"test","transcript_path":""}' \
    | bash "$DIR/hooks/session-start.sh"

# Trigger notification display (populate queue first)
echo '[{"id":"test","name":"Test","points":99,"description":"A test"}]' \
    > "$DIR/notifications.json"
echo '{"session_id":"x","transcript_path":""}' \
    | bash "$DIR/hooks/stop.sh"
```

## Adding a New Achievement — Quickstart

Every achievement needs:
1. An entry in `data/definitions.json`
2. Something that increments its counter (hook or stop.sh)
3. A row added to `docs/achievement_list.md` — **name, description, points, category, skill level, and tutorial flag must match the JSON exactly**
4. Rebuild the binary: `make dist`

> **Keep in sync:** `data/definitions.json` is the source of truth. Any time you add,
> remove, or modify an achievement (including changing point values, descriptions, or
> skill levels), you **must** make the matching update in `docs/achievement_list.md`.
> These two files are not auto-generated from each other.

### 1. definitions.json entry

```json
{
    "id": "unique_snake_case_id",
    "name": "Display Name",
    "description": "What the user did",
    "points": 20,
    "category": "misc",
    "skill_level": "beginner",
    "condition": { "counter": "my_counter", "threshold": 1 }
}
```

**Categories:** `sessions`, `files`, `shell`, `search`, `mcp`, `plan_mode`, `tokens`,
`commands`, `context`, `specs`, `reviews`, `tests`, `misc`, `rank`

**Skill levels:** `beginner`, `intermediate`, `experienced`, `master`, `impossible`, `secret`

**Point values** should reflect the effort required, modelled on Xbox/Steam conventions.
Use the table below as the baseline — pick a value within the range based on how hard
the specific action is relative to others at that tier:

| Skill level | Points range | Guidance |
|---|---|---|
| `beginner` | 5–20 | Trivial first-time actions = 5; easy counters = 10; moderate effort = 15–20 |
| `intermediate` | 25–50 | Requires consistent use or some deliberate setup |
| `experienced` | 50–75 | High-volume milestones or intentional/obscure actions |
| `master` | 100–175 | Sustained heavy use; rare or difficult to reach thresholds |
| `impossible` | 250–300 | Practically unreachable for most users |
| `secret` | 15–25 | Hidden achievements; value based on difficulty, not rarity alone |
| `rank` (completion) | 50 / 100 / 150 / 250 / 500 | Fixed ladder: beginner → intermediate → experienced → master → all |

Rules of thumb:
- A trivial single-action unlock (first use of a tool, reading any file of a type) = **5 pts**
- "Do X once" beginner achievements ≤ **15 pts**; "Do X 5–10 times" ≤ **20 pts**
- Counter milestones scale: the 10× version of a beginner achievement is intermediate, 100× is experienced, 1000× is master
- `lucky_7s` is intentionally **77 pts** — thematic exceptions are fine, but document why
- Rank/completion achievements use fixed values; do not invent new points for those

**Tutorial flag:** Add `"tutorial": true` to include in `/get-started` guided tour. The
interactive tour includes 18 beginner achievements and is driven by this flag.

**Secret achievements:** Add `"secret": true` — `cheevos show` renders `???` for the
description so the condition is hidden from the user.

### 2. Condition types (in `go/internal/engine/engine.go`)

| type field | behaviour |
|---|---|
| *(omitted / "counter")* | `counters[counter] >= threshold` — the default |
| `"all_of_level"` | All non-rank achievements of `level` are unlocked. Optional `"requires": "id"` prerequisite. |
| `"all_unlocked"` | Every achievement except this one is unlocked. Optional `"requires"`. |
| `"all_tutorial"` | All `tutorial: true` achievements are unlocked. |
| `"unlocked_count_gte"` | `unlocked.length >= threshold` (meta count milestone). |

Rank/special conditions omit the `"counter"` and `"threshold"` keys — `cheevos show`
checks for a zero threshold with empty counter to skip progress display.

## How Counters Are Tracked

### post-tool-use.sh (async, fires after every tool call)

The hook parses stdin JSON and builds `_COUNTER_UPDATES`, then calls `cheevos update`.
Add a new counter by extending the relevant `case` branch. Input is read from stdin as JSON:
- `tool_name` — the tool used
- `tool_input.*` — the tool's arguments

**Patterns:**

```bash
# Bash command content
CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // ""')
if [[ "$CMD" == *"some pattern"* ]]; then
    COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"my_counter": 1}')
fi

# File path (Write case already extracts FILE_PATH and FILE_BASENAME)
if printf '%s' "$FILE_BASENAME" | grep -qi "^pattern"; then
    COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"my_counter": 1}')
fi

# MCP tool name
if [[ "$TOOL" == *"specific_tool_name"* ]]; then
    COUNTER_UPDATES=$(printf '%s' "$COUNTER_UPDATES" | jq '. + {"my_counter": 1}')
fi
```

**Important:** Always use incremental jq builds (`'. + {"key": 1}'`) rather than
reassigning the whole JSON string, to allow multiple counters to combine.

**`easter_egg_unlocks`** is incremented manually by running:
`~/.claude/achievements/cheevos award easter_egg_unlocks` — Claude should do this
when the user asks to unlock "Hey Unlock This." `cheevos award` validates the counter
name against the embedded definitions and rejects any counter not used by an achievement.

**Bash 3.2 note:** Use `grep -qi` for case-insensitive matching, not `${var^^}`.
Use `if/fi` not `[[ ]] && action` to avoid `set -e` exits on false conditions.

### session-start.sh (sync, fires on SessionStart)

Handles three source values:
- `"startup"` — fresh session (streak, concurrent, time-based, session count)
- `"resume"` — session resumed (increments `session_resumes`, then exits)
- anything else — exits without tracking

Also fires `cheevos update-defs &` in background for the daily auto-update check.

Counter updates built incrementally into `UPDATES` JSON, then signed and passed to `cheevos update`.

**Adding time-based achievements:** Add a time check block using `HOUR` and `DOW`
(already extracted). Append to `UPDATES` with jq:

```bash
HOUR=$(printf '%d' "$(date +%H)")   # 0–23
DOW=$(printf '%d' "$(date +%u)")    # 1=Mon … 5=Fri … 7=Sun

if (( CONDITION )); then
    UPDATES=$(printf '%s' "$UPDATES" | jq '. + {"my_counter": 1}')
fi
```

`_COUNTER_SETS` is also exported for absolute-value writes (streak tracking):
`{"streak_days": N, "last_session_epoch": EPOCH}`.

### pre-compact.sh (sync, fires before context compaction)

- `trigger == "manual"` → increments `manual_compacts`, then exits
- `trigger == "auto"` → increments `auto_compacts`; also checks transcript for 1M+ context tokens → increments `million_context_fills` if so

### stop.sh (sync, fires at end of every assistant turn)

**Primary roles:**
1. Transcript analysis (model tracking, phrase detection, code review quality)
2. `cheevos drain` → emits `systemMessage` to display unlock notifications
3. `cheevos leaderboard-sync &` → fire-and-forget score push (if leaderboard enabled)

**Transcript analysis** reads the last 20 KB of the transcript via `tail -c 20000` and
runs a single jq pass to extract multiple signals. The result is a JSON object:

```json
{
    "model": "claude-...",
    "sorry": true/false,
    "great_question": true/false,
    "lucky": true/false,
    "no_issues": true/false,
    "many_issues": true/false,
    "code_review_turn": true/false
}
```

**Adding a new phrase detection achievement:**

1. Add a boolean field to the jq object in stop.sh:
```jq
my_phrase: ($text | ascii_downcase | test("phrase to detect")),
```

2. Extract and increment the counter in the bash logic block:
```bash
MY_PHRASE=$(printf '%s' "$TRANSCRIPT_INFO" | jq -r '.my_phrase')
if [[ "$MY_PHRASE" == "true" ]]; then
    COUNTER_EXTRA=$(printf '%s' "$COUNTER_EXTRA" | jq '. + {"my_phrase_said": 1}')
fi
```

3. Update the fallback echo at the end of the jq call to include `"my_phrase":false`.

The `$text` variable is the last assistant message's full text content (joined from
content blocks if it's an array). `ascii_downcase` is applied before `test()`.

**Model tracking** runs once per session (gated by `last_session_model_check` session ID).
New models are added to `state.models_used[]` and `counters.unique_models_used` increments.

### Notification System

When the engine unlocks achievements, it appends notification objects to
`notifications.json`. At the end of each turn, `cheevos drain` drains that queue under
lock, then emits a `systemMessage` JSON blob that Claude Code displays inline:

```json
{"systemMessage": "🏆 Achievement Unlocked!\n  [Name +N pts] Description\nTotal Score: X pts"}
```

`cheevos drain` also fires desktop notifications:
- **macOS** — `osascript` with `display notification` (uses "Glass" sound)
- **Linux** — `notify-send` (if available)
- **Windows** — PowerShell Toast via `Windows.UI.Notifications`

Multiple unlocks in one turn are batched into a single notification.

### Locking

`go/internal/lock/lock.go` uses:
- **macOS/Linux** — `syscall.Flock` with 5-second timeout, 100ms retry interval
- **Windows** — `LockFileEx` via `golang.org/x/sys/windows`

If the lock times out (e.g. two async hooks collide), `cheevos update` exits 1 and the
hook propagates the error. This is acceptable for a fun achievement system.

### HMAC Hook Validation

Each hook signs its payload before calling `cheevos update`. The binary verifies the
signature and rejects calls with a stale timestamp (> 10 seconds old).

The HMAC secret is baked into the binary at compile time (XOR-obfuscated so `strings`
doesn't reveal it), and extracted into `lib.sh` at install time by `install.sh` via
`cheevos print-hmac-secret`. The secret is visible in the installed `lib.sh` — this is
intentional; the hooks are not a trust boundary. Real secrecy lives in the encrypted
`state.json`.

## cheevos Binary — The Core Engine

The binary (`go/cmd/cheevos/`) replaces all stateful bash scripts. All subcommands:

| Subcommand | Replaces / Purpose |
|---|---|
| `cheevos update` | state-update.sh — apply counters, check achievements, save encrypted state |
| `cheevos init` | init_state() — create .key, state.json, notifications.json if absent |
| `cheevos seed <cache>` | seed-state.sh — pre-unlock session achievements on first install |
| `cheevos statusline` | statusline-wrapper.sh — render score for status bar |
| `cheevos show [flags]` | show-achievements.sh — list achievements with ANSI formatting |
| `cheevos serve` | Launch achievement browser web UI, open browser |
| `cheevos award <counter>` | award.sh — manually increment a counter (Easter eggs) |
| `cheevos drain` | Notification drain block in stop.sh — emit systemMessage + OS notify |
| `cheevos update-defs [--force]` | check-updates.sh — fetch new defs from GitHub (once/day) |
| `cheevos leaderboard-sync` | PUT score to leaderboard API (spawned by `drain` on unlock) |
| `cheevos leaderboard-delete` | DELETE user entry from leaderboard (called by uninstall flow) |
| `cheevos verify` | verify-install.sh — health check the installation |
| `cheevos print-hmac-secret` | (install-time) extract HMAC secret for lib.sh injection |

**State encryption:** `go/internal/store/EncryptedJSONStore` wraps the `StateStore`
interface. The on-disk format is `{"v":1,"n":"<nonce>","c":"<ciphertext>"}` — opaque to
`jq`. To add SQLite later, implement `StateStore` in a new file and swap in `main.go`.

**Definitions embed:** `go/internal/defs/definitions.json` is copied from `data/` by the
Makefile before build. `cheevos show` and the engine always use this embedded copy.
`cheevos update-defs` writes new achievements to an on-disk override at
`~/.claude/achievements/definitions.json` which `defs.LoadWithOverride()` prefers.

## Building the Binary

```bash
# Production build for current platform (auto-generates HMAC key)
make prod

# Cross-compile all platforms into dist/
make dist

# Cross-compile + package per-platform zips into dist/
make dist-zip

# Run tests
make test
```

`data/definitions.json` must be copied to `go/internal/defs/definitions.json` before
building — the Makefile does this automatically. The copy is gitignored.

The AES-256 state key is derived at runtime from the compile-time HMAC secret via
HKDF — there is no separate `.key` file. The same binary always produces the same
encryption key, so leaderboard secrets encrypted with `go/tools/keygen` will only
decrypt correctly when the matching binary (built with the same `CHEEVOS_HMAC_KEY`) is installed.

## All Known Counters

| Counter | Incremented by |
|---|---|
| `sessions` | session-start (startup source) |
| `session_resumes` | session-start (resume source) |
| `files_written` | Write, Edit, MultiEdit |
| `files_read` | Read |
| `bash_calls` | Bash |
| `web_searches` | WebSearch, WebFetch |
| `glob_grep_calls` | Glob, Grep |
| `skill_calls` | Skill |
| `github_mcp_calls` | mcp__github__* |
| `jira_mcp_calls` | mcp__confluence__* |
| `total_mcp_calls` | all mcp__* tools |
| `commands_created` | Write to .claude/commands/*.md |
| `spec_files_written` | Write to openapi.*/swagger.*/asyncapi.* or /spec(s)/ dirs |
| `claude_md_written` | Write to CLAUDE.md |
| `test_files_written` | Write to *.test.*, *_test.*, test_*.* etc. |
| `readme_reads` | Read/Write/Edit of README* files |
| `todo_comments_added` | Edit where new_string contains TODO or FIXME |
| `git_commits` | Bash: `git commit` |
| `pull_requests` | Bash: `gh pr create` or mcp create_pull_request |
| `force_pushes` | Bash: `git push --force` (not --force-with-lease) |
| `kill9_calls` | Bash: `kill -9` |
| `sudo_calls` | Bash: `sudo ` |
| `auto_compacts` | pre-compact (trigger == auto) |
| `manual_compacts` | pre-compact (trigger == manual) |
| `million_context_fills` | pre-compact (auto + transcript tokens >= 1M) |
| `code_reviews` | Skill with "review" in name, or mcp pull_request_review_write submit_pending |
| `perfect_reviews` | stop.sh: code review turn + no-issues language in response |
| `thorough_reviews` | stop.sh: code review turn + numbered items reaching 10+ |
| `test_runs` | Bash: pytest/jest/go test/cargo test/rspec/etc. |
| `plan_mode_sessions` | post-tool-use.sh: `ExitPlanMode` tool |
| `tokens_consumed` | stop.sh: output_tokens from last assistant message, per turn |
| `task_calls` | post-tool-use.sh: `Task` tool |
| `dangerous_launches` | session-start.sh: `ps -p $PPID` check for `--dangerously-skip-permissions` |
| `concurrent_sessions_5` | session-start: pgrep -f "[/]claude$" count >= 5 |
| `streak_days` | session-start: consecutive-day counter (set via _COUNTER_SETS) |
| `last_session_epoch` | session-start: days-since-epoch (set via _COUNTER_SETS) |
| `midnight_sessions` | session-start: HOUR < 5 |
| `friday_sessions` | session-start: DOW == 5 && HOUR >= 16 |
| `unique_models_used` | stop.sh: new model detected in transcript |
| `apologies` | stop.sh: "sorry" in last response |
| `great_question_said` | stop.sh: "great question" in last response |
| `lucky_sessions` | stop.sh: output_tokens == 777 |
| `easter_egg_unlocks` | award subcommand (manual) |
| `self_reads` | Read: path contains /.claude/achievements/ |

## state.json Schema (encrypted — fields listed for reference)

```json
{
    "schema_version": 1,
    "score": 0,
    "counters": { "sessions": 0, ... },
    "unlocked": ["achievement_id", ...],
    "unlock_times": { "achievement_id": "2026-01-01T00:00:00Z", ... },
    "models_used": ["claude-...", ...],
    "last_session_model_check": "session-id-string",
    "last_update_check_epoch": 0,
    "last_updated": "2026-01-01T00:00:00Z"
}
```

The file is AES-256-GCM encrypted. `jq` on the raw file returns `null` for all fields.
Use `cheevos show` to inspect state.

## Rank Achievement Chain

Rank achievements form a prerequisite ladder enforced by `"requires": "id"` in their conditions:

```
tutorial_complete ("Graduate")           — all_tutorial
graduation_day ("Graduation Day")        — all_of_level: beginner
    ↓ requires graduation_day
middle_management ("Middle Management")  — all_of_level: intermediate
    ↓ requires middle_management
elite_operator ("Elite Operator")        — all_of_level: experienced
    ↓ requires elite_operator
efficiency_grandmaster                   — all_of_level: master
    ↓ requires efficiency_grandmaster
beyond_the_claudeverse                   — all_unlocked (every other achievement)

meta_50 ("Achievement Unlocked: Achievement") — unlocked_count_gte: 50 (independent)
```

`all_of_level` checks non-rank achievements only (`.category != "rank"`).
Rank achievements cascade naturally — since the engine checks against the pre-update
unlocked list, cascades take effect on the *next* tool call (one turn of latency).

## First Install: cheevos seed

On first install (no existing `state.json`), `cheevos seed` pre-unlocks any session
achievements the user has already earned:

1. Reads `totalSessions` from `~/.claude/stats-cache.json`
2. Unlocks all session-based achievements whose threshold ≤ existing session count
3. Calculates the starting score from those pre-unlocked achievements
4. Writes the initial encrypted `state.json`

On upgrade (existing `state.json`), seed is skipped — state is preserved.
Plaintext `state.json` from the bash era is migrated to encrypted format transparently
on the first `cheevos update` call.

## Status Bar

`install.sh` sets `statusLine.command` to `~/.claude/achievements/cheevos statusline`.
The binary outputs the score and, for 5 minutes after an unlock, the achievement name:

```
🏆 560 pts
```

If the user had a custom statusLine before install, it's saved in `.original-statusline`
and called first; the achievement segment is appended after `" | "`.

## Interactive Guided Tour (/get-started)

The `/get-started` slash command provides an interactive guided tour for new users. It walks
them through 19 core tutorial achievements with step-by-step instructions, auto-detecting
completion and advancing automatically.

**Tutorial achievements** are marked with `"tutorial": true` in `definitions.json`. The
guided tour follows a hardcoded optimal order defined in `commands/get-started.md`.

Current tutorial set (19 achievements, 160 pts):
`first_session`, `files_written_first`, `files_read_first`, `bash_first`, `web_search_first`,
`glob_grep_first`, `skill_calls_1`, `model_citizen`, `back_again`, `check_your_vitals`,
`laying_down_the_law`, `git_er_done`, `plan_mode_first`, `code_review_1`, `test_driven`,
`spring_cleaning`, `github_first`, `delegation_station`, `inner_machinations`

**How it works:**
1. User runs `/get-started` in a Claude Code session
2. Claude checks which tutorial achievements are already unlocked
3. Claude displays an overview, then guides the user through each uncompleted achievement
4. After each achievement unlocks, Claude automatically moves to the next one
5. User can type "skip" to move ahead without completing an achievement
6. When all 18 are complete, Claude displays a trophy case celebration

**To modify the tour:** Edit `commands/get-started.md`. Each achievement has a detailed
step-by-step guide with examples. The optimal order and all instructional content is defined
in that file — no Go code changes needed for tutorial content updates.

## cheevos show Filters

**Unlock status:** `--all` / `-a`, `--unlocked` / `-u`, `--locked` / `-l`

**Skill level:** `--beginner` / `-B`, `--intermediate` / `-I`, `--experienced` / `-E`, `--master` / `-M`, `--secret` / `-S`

Flags are combinable: `cheevos show --locked --beginner`

When run in a terminal with **no flags**, it shows two sequential numbered prompts:
1. Unlock status (All / Unlocked only / Locked only)
2. Skill level filter (All levels / Beginner / Intermediate / Experienced / Master / Secret)

Categories displayed in order (add new ones to the `categories` slice in `go/cmd/cheevos/subcmd/show.go`):
`sessions`, `files`, `shell`, `search`, `mcp`, `plan_mode`, `tokens`, `commands`,
`context`, `specs`, `reviews`, `tests`, `misc`, `rank`

## install.sh Checklist

When adding new hook scripts, add a `cp` line in the hooks block in `go/install.sh`
and add the hook registration to the jq merge block (Phase 2). The jq merge is
idempotent — it checks for exact command string before adding.

When adding new utility scripts, add a `cp` line in the shared-scripts block before `chmod +x`,
and add a thin shim in `go/scripts/`.

**Phase 1.6 — Slash commands:** copies `commands/achievements.md`,
`commands/get-started.md`, and `commands/uninstall-achievements.md` to
`~/.claude/commands/`. Also copies `uninstall.sh` itself into
`$ACHIEVEMENTS_DIR/uninstall.sh` so the slash command can find it without knowing
the repo path.

**Phase 3.5 — Auto-allowed commands:** adds permission patterns for `cheevos drain`
and `cheevos show` to the allow list. These commands are used repeatedly during the
`/get-started` interactive tutorial. The patterns use wildcards (`*/.claude/achievements/cheevos`)
to match any path expansion (tilde, $HOME, or full path) and trailing `*` to match
flags, pipes, and redirects. This prevents repetitive permission prompts during the
tutorial flow and improves user experience.

**Phase 6.5 — Leaderboard configuration:**
- `--leaderboard-secret SECRET` arg parsed before Phase 0
- If arg provided → generates UUID → writes enabled `leaderboard.conf` with `LEADERBOARD_SECRET=<blob>` → `chmod 600`
- If no arg and conf exists → preserves (upgrade path)
- If no arg and no conf → writes disabled stub with empty `LEADERBOARD_SECRET=`
- `leaderboard.conf` is never overwritten on upgrade unless `--leaderboard-secret` is re-supplied
- Secret is an AES-256-GCM encrypted blob produced by `go run ./go/tools/keygen --token ... --api-url ...`

## Common Gotchas

- **`set -e` + arithmetic:** `(( expr ))` exits if it evaluates to 0. Use `if (( )); then`
  or `$(( ))` assignment forms. Never use `(( var++ ))` when `var` might be 0.
- **Bash 3.2 compat (macOS):** No `${var^^}` (uppercase). Use `grep -qi` or `tr '[:lower:]' '[:upper:]'`.
  No `mapfile`/`readarray`. Use `while IFS= read -r line; do ... done < <(...)`.
  No `declare -A` (associative arrays). Use `case` statements, TSV variables with
  `grep`+`cut` lookups, or newline-delimited strings with `grep -qx` for set membership.
- **Single quotes inside single-quoted jq strings:** The jq expressions in `stop.sh` and
  other hooks are passed as single-quoted strings (`'...'`). You **cannot** embed a literal
  single quote inside a single-quoted bash string. Instead:
  - Use `.` (match any char) instead of a literal `'` in regex patterns: `i(.ve)?` not `i('ve)?`
  - Use `.?` instead of `'?`: `you.?re` not `you'?re`
  - **Always run `bash -n script.sh`** after editing any hook to catch these issues.
- **Rebuild after changing definitions:** `data/definitions.json` is embedded at compile
  time. Any change to it requires rebuilding the binary and redistributing `dist/`.
- **Hook HMAC validation:** If a hook call fails HMAC verification, `cheevos update`
  exits 1 and the hook propagates the error (hook error in Claude Code). This usually
  means the HMAC secret in `lib.sh` doesn't match the binary — re-run `install.sh` to fix.
- **Async hook race:** `post-tool-use.sh` is async. `stop.sh` is synchronous and runs
  after the async hook — notifications are queued in `notifications.json` for this reason.
- **State file is encrypted:** Never try to read `state.json` with `jq` directly.
  Use `cheevos show` or `cheevos verify` to inspect state.
- **`head -n -1` is GNU-only:** BSD head (macOS) does not support negative line counts and
  exits non-zero, which under `set -euo pipefail` kills the script before the next line runs.
  Use `sed '$d'` to strip the last line instead — it is POSIX and works on both macOS and Linux.
  This bug caused `leaderboard-sync.sh` to silently skip the log write on every *successful*
  API call (non-empty curl output), so only failures (empty output) ever reached the log.
- **`commands/` slash commands are not inside `~/.claude/achievements/`:** They live in
  `~/.claude/commands/` and are installed by Phase 1.6. The uninstall slash command references
  `~/.claude/achievements/uninstall.sh` (a copy placed there by install.sh), not the repo file.

## Verifying Changes

After editing any hook or script:

```bash
# Syntax-check all hooks and scripts
for f in hooks/*.sh scripts/*.sh; do
    bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"
done

# After any Go changes, verify the build compiles:
cd go && go vet ./... && go build ./...

# After installing
bash install.sh
~/.claude/achievements/cheevos verify
```

Common symptoms of quoting bugs:
- `unexpected EOF while looking for matching \`"'` — an unescaped single quote inside a
  single-quoted string (the error line number points to the *end* of the broken string)
- `unexpected EOF while looking for matching \`)'` — same cause but inside `$(...)`
- `syntax error near unexpected token \`)'` — broken surrounding quotes
