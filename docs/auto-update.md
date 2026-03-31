# Auto-Updates

The achievement system automatically checks the public GitHub repo for new achievement
definitions once per day on session startup.

## How It Works

1. On every new session, `session-start.sh` triggers `cheevos update-defs` in the background
2. Checks run at most once per 24 hours to avoid GitHub API rate limits
3. New achievements (identified by ID) are merged into a local override file at
   `~/.claude/achievements/definitions.json`
   - Existing achievements are never modified or removed
   - Your score, counters, and unlocked achievements are always preserved
4. When new achievements are added you get a desktop notification

## Manual Update

```bash
~/.claude/achievements/cheevos update-defs --force
```

## Disabling

Remove the `cheevos update-defs &` line from `~/.claude/achievements/hooks/session-start.sh`.
Manual updates with `--force` will still work.

## Source

Definitions are fetched from `KyleLavorato/claude-cheevos` (`main` branch, `data/definitions.json`).

## Security

Downloaded JSON is validated before merging. If the remote file is unreachable, invalid JSON,
or missing the expected structure, the update is silently skipped with no changes to your
local definitions.
