# Auto-Updates

The achievement system automatically checks the public GitHub repo for both new achievement
definitions and binary updates once per day on session startup.

## What Gets Updated

### Achievement Definitions

New achievements (identified by unique ID) are merged into your local override file at
`~/.claude/achievements/definitions.json`:

- Existing achievements are never modified or removed
- Your score, counters, and unlocked achievements are always preserved
- When new achievements are added, you get a desktop notification

### Binary and Hook Updates

The `cheevos` binary and all hook scripts are automatically updated to the latest GitHub release:

- Downloads are verified with SHA256 checksums
- Updates are atomic with automatic rollback on failure
- The binary is sanity-checked before committing the update
- Your encrypted state and HMAC secret are automatically preserved
- Hook scripts (`hooks/*.sh`, `scripts/lib.sh`) and slash commands are replaced from the same verified zip
- The HMAC secret is automatically re-injected into `lib.sh` on the next binary invocation

## How It Works

1. On every new session, `session-start.sh` triggers `cheevos check-updates` in the background
2. Checks run at most once per 24 hours to avoid GitHub API rate limits
3. Network failures are silent — no error messages if GitHub is unreachable
4. Updates happen in the background and never block your session startup

## Custom Compilations

If you built the binary from source (not from an official release), binary auto-updates are
**automatically disabled**. The system detects custom builds when `cheevos version` reports `dev`.

- **Achievement definitions:** Still auto-update (you get new achievements)
- **Binary updates:** Disabled (you're not tracking an official release)
- **Force flag:** Even `--force` won't enable binary updates for custom builds

To re-enable binary auto-updates, install an official release from GitHub.

## Checking Your Version

Inside a Claude session:

```
/achievements-version
```

From the terminal:

```bash
~/.claude/achievements/cheevos version
```

## Manual Updates

Force an immediate check (bypasses the 24-hour rate limit):

```bash
# Check both definitions and binary
~/.claude/achievements/cheevos check-updates --force

# Check only definitions
~/.claude/achievements/cheevos update-defs --force

# Check only binary
~/.claude/achievements/cheevos update-binary --force
```

## Opting Out

To disable binary auto-updates while keeping definition updates:

```bash
touch ~/.claude/achievements/.no-auto-update
```

When this file exists, `update-binary` and `check-updates` will skip binary updates.
Achievement definition updates continue normally.

To re-enable binary auto-updates:

```bash
rm ~/.claude/achievements/.no-auto-update
```

## Fully Disabling Auto-Updates

To disable all automatic updates (both definitions and binary):

Edit `~/.claude/achievements/hooks/session-start.sh` and remove or comment out the line:

```bash
"$CHEEVOS" check-updates &
```

Manual updates with `--force` will still work.

## Source

- **Definitions:** Fetched from `KyleLavorato/claude-cheevos` (`main` branch, `data/definitions.json`)
- **Binary releases:** Downloaded from GitHub releases at `KyleLavorato/claude-cheevos/releases/latest`

## Security

### Definition Updates

Downloaded JSON is validated before merging. If the remote file is unreachable, invalid JSON,
or missing the expected structure, the update is silently skipped with no changes to your
local definitions.

### Binary Updates

Multiple security measures protect binary updates:

1. **SHA256 verification:** Every download is checksummed against the official `SHA256SUMS` file
2. **Atomic replacement:** The old binary is backed up before the new one is installed
3. **Sanity check:** The new binary must successfully run `cheevos version` before committing
4. **Automatic rollback:** If the sanity check fails, the backup is automatically restored
5. **HMAC self-healing:** The new binary's HMAC secret is automatically injected into `scripts/lib.sh`

If any step fails (network error, checksum mismatch, sanity check failure), the update is
aborted and your original binary remains in place.

### Manual Rollback

If you need to manually restore a previous version:

```bash
mv ~/.claude/achievements/cheevos.bak ~/.claude/achievements/cheevos
```

The `.bak` file is created before every successful update.

## Platform Support

Binary auto-updates support the same platforms as manual installation:

- macOS (Apple Silicon and Intel)
- Linux (x86_64 and ARM64)
- Windows (x86_64 via WSL)

The system automatically detects your platform and downloads the correct binary.

## Troubleshooting

**Binary update failed:**

Check `~/.claude/achievements/cheevos.bak` exists and restore it manually if needed.

**Updates not happening:**

- Run `cheevos check-updates --force` to bypass rate limiting
- Check that `~/.claude/achievements/.no-auto-update` doesn't exist
- Verify you're not using a custom build (`cheevos version` should not show `dev`)
- Check your internet connection

**Custom build detecting as official release:**

Custom builds must be compiled without the `VERSION` variable:

```bash
# Wrong (sets version)
VERSION=v1.0.0 make prod

# Correct (uses default "dev")
make prod
```
