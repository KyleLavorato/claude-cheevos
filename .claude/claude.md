# cheevos — Claude Code Achievement System

A self-contained achievement system for Claude Code that tracks usage milestones via hooks,
awards points, and displays the score in the status bar. Installed to `~/.claude/achievements/`.

## Project Layout

```
cheevos/
├── data/definitions.json        # All achievement definitions (source of truth)
├── hooks/
│   ├── session-start.sh         # SessionStart hook — sessions, streak, time-based, concurrent
│   ├── post-tool-use.sh         # PostToolUse hook (async) — all tool-use counter tracking
│   ├── pre-compact.sh           # PreCompact hook — auto-compact and manual compact tracking
│   └── stop.sh                  # Stop hook — transcript analysis + notification drain
├── scripts/
│   ├── lib.sh                   # Shared library: paths, init_state(), with_lock()
│   ├── state-update.sh          # Atomic state writer, called under lock by all hooks
│   ├── statusline-wrapper.sh    # Status bar display
│   ├── seed-state.sh            # First-install state seeder (reads stats-cache.json)
│   ├── show-achievements.sh     # Achievement list UI with unlock/level filters
│   ├── learning-path.sh         # Tutorial UI driven by "tutorial": true in definitions
│   └── award.sh                 # Manual counter increment for Easter egg achievements
├── install.sh                   # Idempotent installer — copies files, patches settings.json
├── uninstall.sh                 # Removes hooks from settings.json, optionally deletes state
└── README.md
```

Installed runtime lives at `~/.claude/achievements/` (state never touched on reinstall).

## Runtime Files (installed to `~/.claude/achievements/`)

| File | Purpose |
|---|---|
| `state.json` | Score, counters, unlocked list, models_used, streak data |
| `definitions.json` | Achievement definitions (copied from repo on every install) |
| `notifications.json` | Queue of pending unlock notifications (`[]` when empty) |
| `state.lock` | Lockfile for `with_lock` (never delete manually) |
| `.version` | Installed version string — used by install.sh for upgrade detection |
| `.original-statusline` | Prior `statusLine.command` value saved for uninstall restoration |
| `hooks/`, `scripts/` | All scripts copied from repo (safe to overwrite on upgrade) |

## Install and Test

```bash
bash install.sh        # idempotent, safe to run multiple times
bash uninstall.sh      # restores original statusLine, removes hooks

# View achievements
bash ~/.claude/achievements/scripts/show-achievements.sh [--unlocked] [--beginner]
bash ~/.claude/achievements/scripts/learning-path.sh

# Award an Easter egg counter manually
bash ~/.claude/achievements/scripts/award.sh easter_egg_unlocks

# Verify state
jq . ~/.claude/achievements/state.json
```

After install, restart Claude Code for hooks to take effect.

### Manual Hook Testing

Hooks read JSON from stdin. Pipe a payload directly to test without running Claude:

```bash
DIR=~/.claude/achievements

# Test a bash command counter (bash_calls)
echo '{"tool_name":"Bash","tool_input":{"command":"echo hello"}}' \
    | bash "$DIR/hooks/post-tool-use.sh"
jq '.counters.bash_calls' "$DIR/state.json"

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
2. Something that increments its counter (hook, stop.sh, etc.)
3. A row added to `docs/achievement_list.md`

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

**Skill levels:** `beginner`, `intermediate`, `experienced`, `master`, `impossible`

**Tutorial flag:** Add `"tutorial": true` to include in `learning-path.sh`. The learning
path is driven entirely by this flag — no script changes needed.

### 2. Condition types (in `state-update.sh`)

| type field | behaviour |
|---|---|
| *(omitted / "counter")* | `counters[counter] >= threshold` — the default |
| `"all_of_level"` | All non-rank achievements of `level` are unlocked. Optional `"requires": "id"` prerequisite. |
| `"all_unlocked"` | Every achievement except this one is unlocked. Optional `"requires"`. |
| `"all_tutorial"` | All `tutorial: true` achievements are unlocked. |
| `"unlocked_count_gte"` | `unlocked.length >= threshold` (meta count milestone). |

Rank/special conditions omit the `"counter"` and `"threshold"` keys — `show-achievements.sh`
checks for `threshold == "null"` to skip progress display.

## How Counters Are Tracked

### post-tool-use.sh (async, fires after every tool call)

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

**MultiEdit note:** `MultiEdit` tool_input uses an `edits` array (`tool_input.edits[].file_path`).
Use `jq -r '.tool_input.edits[]?.file_path'` to extract all target file paths and grep them for
patterns (README, test files, etc.).

**Intentional gap — Write and TODO/FIXME:** `todo_comments_added` is only tracked in `Edit`
(via `tool_input.new_string`), not `Write`. This is intentional: `new_string` is exactly the
text being inserted, so it's a precise signal. A `Write` content check would produce false
positives from templates and boilerplate files that happen to contain TODO comments.

**`easter_egg_unlocks`** is incremented manually by running:
`bash ~/.claude/achievements/scripts/award.sh easter_egg_unlocks` — Claude should do this
when the user asks to unlock "Hey Unlock This."

**Bash 3.2 note:** Use `grep -qi` for case-insensitive matching, not `${var^^}`.
Use `if/fi` not `[[ ]] && action` to avoid `set -e` exits on false conditions.

### session-start.sh (sync, fires on SessionStart)

Handles three source values:
- `"startup"` — fresh session (main branch: streak, concurrent, time-based, session count)
- `"resume"` — session resumed (increments `session_resumes`, then exits)
- anything else — exits without tracking

Counter updates built incrementally into `UPDATES` JSON, then exported as `_COUNTER_UPDATES`.

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
2. Notification queue drain → emits `systemMessage` to display unlock notifications

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

When `state-update.sh` unlocks achievements, it appends the full achievement objects to
`notifications.json`. At the end of each turn, `stop.sh` drains that queue under lock,
then emits a `systemMessage` JSON blob that Claude Code displays inline:

```json
{"systemMessage": "🏆 Achievement Unlocked!\n  [Name +N pts] Description\nTotal Score: X pts"}
```

`stop.sh` also fires desktop notifications:
- **macOS** — `osascript` with `display notification` (uses "Glass" sound)
- **WSL/Windows** — PowerShell Toast via `Windows.UI.Notifications`

Multiple unlocks in one turn are batched into a single notification.

### Locking

`with_lock` in `lib.sh` uses:
- **macOS** — `lockf -k -t 5 "$LOCK_FILE"` (5-second timeout)
- **Linux** — `flock -w 5 -x "$LOCK_FILE"`

If the lock times out (e.g. two async hooks collide), the command fails silently and
the counter update is lost for that event. This is acceptable for a fun achievement system.

## state-update.sh — The Core Engine

Called under lock by every hook via `with_lock bash "$SCRIPTS_DIR/state-update.sh"`.

**Required env vars:** `_STATE_FILE`, `_DEFS_FILE`, `_NOTIFICATIONS_FILE`, `_COUNTER_UPDATES`

**Optional env vars:**
- `_COUNTER_SETS` — JSON object of counter values to SET (not increment). Used for streak.
- `_NEW_MODEL` — Model name to add to `models_used` if not already present.
- `_SESSION_ID` — Records `last_session_model_check` in state.

**Order of operations:**
1. Apply `_COUNTER_UPDATES` increments
2. Apply `_COUNTER_SETS` absolute writes
3. Handle `_NEW_MODEL` deduplication
4. Record `_SESSION_ID`
5. Check all achievements for newly met conditions
6. Update `unlocked[]`, `unlock_times{}`, and `score`
7. Append to `notifications.json`
8. Write state atomically (temp file + mv)

`unlock_times` records a UTC ISO timestamp for each newly unlocked achievement ID in the
same atomic write as the unlock itself.

Newly unlocked notifications are drained by `stop.sh` and emitted as a `systemMessage`.

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
| `github_mcp_calls` | mcp__github__*, mcp__dsgithub__* |
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
| `easter_egg_unlocks` | award.sh (manual) |
| `self_reads` | Read: path contains /.claude/achievements/ |

## state.json Schema

```json
{
    "schema_version": 1,
    "score": 0,
    "counters": { "sessions": 0, ... },
    "unlocked": ["achievement_id", ...],
    "unlock_times": { "achievement_id": "2026-01-01T00:00:00Z", ... },
    "models_used": ["claude-...", ...],
    "last_session_model_check": "session-id-string",
    "last_updated": "2026-01-01T00:00:00Z"
}
```

`unlock_times` maps achievement ID → ISO 8601 UTC timestamp of when it was unlocked.
Achievements unlocked before this field was introduced have no entry (gracefully omitted from display).

New counters are auto-created on first increment via `(.[$key] // 0) + 1` — no migration needed.

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

`all_of_level` checks non-rank achievements only (`.category != "rank"`), so completing
all beginner non-rank achievements unlocks `graduation_day` regardless of rank status.
Rank achievements cascade naturally — unlocking one may make the next checkable, but
since `state-update.sh` checks against the pre-update unlocked list, cascades take effect
on the *next* tool call (one turn of latency).

## First Install: seed-state.sh

On first install (no existing `state.json`), `seed-state.sh` runs to pre-unlock any
session achievements the user has already earned:

1. Reads `totalSessions` from `~/.claude/stats-cache.json`
2. Unlocks all session-based achievements whose threshold ≤ existing session count
3. Calculates the starting score from those pre-unlocked achievements
4. Writes the initial `state.json`

On upgrade (existing `state.json`), `seed-state.sh` is skipped entirely — state is preserved.

## Status Bar (statusline-wrapper.sh)

`install.sh` wraps any existing `statusLine.command` with `statusline-wrapper.sh`.
The wrapper outputs the score and, for 5 minutes after an unlock, the achievement name:

```
🏆 560 pts
🏆 710 pts (Power User!)    ← for 5 min after unlock
```

The wrapper calls the original status line command first (if any), then appends the
achievement score. The original command is saved to `.original-statusline` for uninstall.

## Tutorial System (learning-path.sh)

The tutorial is driven purely by `"tutorial": true` in `definitions.json`. To add/remove
achievements from the tutorial path, set or unset that field — no script changes needed.

Current tutorial set (8 achievements, 165 pts):
`first_session`, `back_again`, `web_search_first`, `files_written_10`,
`laying_down_the_law`, `files_read_100`, `bash_calls_50`, `plan_mode_first`

Tips are hardcoded in `learning-path.sh` inside the `get_tip()` case statement.
Add a new branch for any new tutorial achievement:
```bash
# Inside get_tip() in learning-path.sh:
        my_achievement_id) echo "How to unlock this: ..." ;;
```

## show-achievements.sh Filters

**Unlock status:** `--all` / `-a`, `--unlocked` / `-u`, `--locked` / `-l`

**Skill level:** `--beginner` / `-B`, `--intermediate` / `-I`, `--experienced` / `-E`, `--master` / `-M`

Flags are combinable: `show-achievements.sh --locked --beginner`

When run in a terminal with **no flags**, it shows two sequential `select` prompts:
1. Unlock status (All / Unlocked only / Locked only)
2. Skill level filter (All levels / Beginner / Intermediate / Experienced / Master)

Categories displayed in order (add new ones to the `CATS` array):
`sessions`, `files`, `shell`, `search`, `mcp`, `plan_mode`, `tokens`, `commands`,
`context`, `specs`, `reviews`, `tests`, `misc`, `rank`

## Known Gaps (Future Work)

All four previously untracked counters have now been wired up:

| Counter | How it's now tracked |
|---|---|
| `plan_mode_sessions` | `post-tool-use.sh` — `ExitPlanMode` tool case increments once per completed plan |
| `tokens_consumed` | `stop.sh` — `output_tokens` from the last assistant message added each turn |
| `task_calls` | `post-tool-use.sh` — `Task` tool case |
| `dangerous_launches` | `session-start.sh` — checks `ps -p $PPID -o args=` on startup for `--dangerously-skip-permissions` |

**Notes:**
- `tokens_consumed` tracks **output tokens per turn**, not total (input + output). Output tokens
  are the cleanest measure (no double-counting from repeated context). At ~500 tokens/turn
  average, Token Taster (100k) unlocks after ~200 turns, which is reasonable.
- `dangerous_launches` detection depends on `$PPID` resolving to the Claude process. It fails
  gracefully (no increment) if the process lookup fails or the flag isn't present.
- `ExitPlanMode` fires when the user **approves** a plan and implementation begins, which is
  the most meaningful signal for "entered plan mode intentionally."

Still tracked in `README.md` TODO: **tamper protection** — add HMAC signature to `state.json`
to prevent users from manually editing counters to cheat achievements.

## install.sh Checklist

When adding new scripts, add a `cp` line in the shared-scripts block before `chmod +x`.
When adding new hooks, add a `cp` line in the hooks block and add the hook registration
to the jq merge block (Phase 2). The jq merge is idempotent — it checks for exact
command string before adding.

## Common Gotchas

- **`set -e` + arithmetic:** `(( expr ))` exits if it evaluates to 0. Use `if (( )); then`
  or `$(( ))` assignment forms. Never use `(( var++ ))` when `var` might be 0.
- **Bash 3.2 compat (macOS):** No `${var^^}` (uppercase). Use `grep -qi` or `tr '[:lower:]' '[:upper:]'`.
  No `mapfile`/`readarray`. Use `while IFS= read -r line; do ... done < <(...)`.
  No `declare -A` (associative arrays). Use `case` statements, TSV variables with
  `grep`+`cut` lookups, or newline-delimited strings with `grep -qx` for set membership.
- **Single quotes inside single-quoted jq strings:** The jq expressions in `stop.sh` and
  other hooks are passed as single-quoted strings (`'...'`). You **cannot** embed a literal
  single quote inside a single-quoted bash string — it will silently break the quoting and
  cause an `unexpected EOF` parse error far from the actual problem. Instead:
  - Use `.` (match any char) instead of a literal `'` in regex patterns: `i(.ve)?` not `i('ve)?`
  - Use `.?` instead of `'?`: `you.?re` not `you'?re`
  - The `'"'"'` trick (end-quote, escaped-quote, re-open-quote) does **not** work inside
    `$(...)` command substitutions nested within single-quoted strings.
  - **Always run `bash -n script.sh`** after editing any hook to catch these issues.
- **Heredocs with mixed expansion:** When a heredoc contains both bash variables to expand
  and literal `$` characters (e.g. PowerShell variables), use a **quoted** heredoc
  (`<< 'EOF'`) with placeholder substitution via `sed`, rather than an unquoted heredoc
  with `\$` escaping. The unquoted approach is fragile with nested `$(...)` subshells
  and embedded single quotes.
- **Locking:** All state writes go through `with_lock bash "$SCRIPTS_DIR/state-update.sh"`.
  Never write state.json directly without the lock.
- **Async hook race:** `post-tool-use.sh` is async. `stop.sh` is synchronous and runs
  after the async hook — notifications are queued in notifications.json for this reason.
- **jq null handling:** Missing counter fields default to 0 via `// 0`. Missing array
  fields default to `[]` via `// []`. Rank achievements have `condition.threshold == null`
  in the @tsv output — check for this in display code.
- **COUNTER_UPDATES building:** Always start from a base JSON object and add keys with jq
  `'. + {"key": 1}'`. This allows multiple counters per tool call without if/elif ladders.

## Verifying Changes

After editing **any** hook or script, always run a syntax check before installing:

```bash
# Syntax-check all hooks and scripts (catches quoting errors, missing quotes, etc.)
for f in hooks/*.sh scripts/*.sh; do
    bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"
done
```

Then copy to the installed location and verify again:

```bash
bash install.sh
for f in ~/.claude/achievements/hooks/*.sh ~/.claude/achievements/scripts/*.sh; do
    bash -n "$f" && echo "OK: $f" || echo "FAIL: $f"
done
```

Common symptoms of quoting bugs:
- `unexpected EOF while looking for matching \`"'` — an unescaped single quote inside a
  single-quoted string (the error line number points to the *end* of the broken string,
  not the offending quote)
- `unexpected EOF while looking for matching \`)'` — same cause, but bash is looking for
  the close of a `$(...)` subshell that was broken by a stray quote
- `syntax error near unexpected token \`)'` — a `)` that bash sees as shell syntax
  because the surrounding quotes were broken
