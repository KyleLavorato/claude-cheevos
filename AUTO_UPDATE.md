# Auto-Update System

The achievement system automatically checks the public GitHub repo for new achievement definitions once per day on session startup.

## How It Works

1. **Automatic checks**: On every new Claude Code session, `session-start.sh` triggers `check-updates.sh` in the background
2. **Rate limiting**: Checks only run once per 24 hours to avoid API rate limits
3. **Smart merging**: New achievements (by ID) are appended to your local `definitions.json`
   - Existing achievements are never modified or removed
   - Your unlocked achievements and progress are preserved
4. **Notifications**: When new achievements are added, you'll get a desktop notification

## Manual Update Check

Force an immediate update check:

```bash
bash ~/.claude/achievements/scripts/check-updates.sh --force
```

## Configuration

The update system fetches from:
- **Repo**: `KyleLavorato/claude-cheevos`
- **Branch**: `main`
- **File**: `data/definitions.json`

To change the source repo, edit `GITHUB_REPO` and `GITHUB_BRANCH` in:
`~/.claude/achievements/scripts/check-updates.sh`

## State Tracking

The last update check timestamp is stored in `state.json`:
```json
{
  "last_update_check_epoch": 1774893197
}
```

## Disabling Auto-Updates

To disable automatic update checks, remove these lines from `session-start.sh`:

```bash
# Auto-update check (once per day, runs in background)
bash "$SCRIPTS_DIR/check-updates.sh" &
```

You can still manually trigger updates with the `--force` flag.

## Security Note

The update system validates downloaded JSON before merging. If the remote file is:
- Unreachable (network error)
- Invalid JSON
- Missing the expected structure

...the update is silently skipped with no changes to your local definitions.

## Testing

To test the update mechanism with a dry run:

```bash
# Check what the remote definitions look like
curl -s https://raw.githubusercontent.com/KyleLavorato/claude-cheevos/main/data/definitions.json | jq '.achievements[] | .id' | head -20

# Compare with your local definitions
jq '.achievements[] | .id' ~/.claude/achievements/definitions.json | head -20

# Force an update check (will show notification if new achievements exist)
bash ~/.claude/achievements/scripts/check-updates.sh --force
```
