# Developing claude-cheevos

## Contents

[Building from Source](#building-from-source) · [Adding Custom Achievements](#adding-custom-achievements) · [Bash 3.2 Constraints](#bash-32-constraints-macos)

---

## Building from Source

### Prerequisites

- Go 1.21+
- `make`
- `jq` (already required at runtime)

### Make targets

All commands must be run from the **repository root**, not from `go/`.

| Command | What it does |
|---|---|
| `make prod` | Build for the current platform → `dist/cheevos-<os>-<arch>` |
| `make dist` | Cross-compile all 5 platforms → `dist/cheevos-*` |
| `make dist-zip` | Run `dist`, then package per-platform zips → `dist/claude-cheevos-*.zip` |
| `make test` | Run the Go test suite |
| `make clean` | Remove `dist/` |

### HMAC key

The HMAC key is baked into the binary at compile time and used to derive the AES-256
encryption key for `state.json` and leaderboard credentials. If you don't supply one,
the Makefile generates a fresh random key automatically on every build.

Keep the key if you plan to generate or regenerate the leaderboard secret without
rebuilding the binary — the secret can only be decrypted by a binary built with the
matching key.

```bash
# Simple build — auto-generates a new key each time
make dist-zip

# Save the key first, then build with it (required if you also need a leaderboard secret)
CHEEVOS_HMAC_KEY=$(cd go && go run ./tools/keygen)
CHEEVOS_HMAC_KEY="$CHEEVOS_HMAC_KEY" make dist-zip
```

### Generating a leaderboard secret

The leaderboard secret is an AES-256-GCM encrypted blob containing the API token
and URL. It is generated with `go run ./go/tools/keygen` and must be produced using
the same `CHEEVOS_HMAC_KEY` that was used to build the distributed binary.

The tool (`go/tools/keygen`) operates in three modes:

**Mode 1 — HMAC key only** (no flags, original Makefile behaviour):
```bash
cd go && go run ./tools/keygen
# Output: <obfuscated-key>
```

**Mode 2 — fresh key + leaderboard secret** (new binary and new secret together):
```bash
cd go && go run ./tools/keygen --token <api-token> --api-url <api-url>
# Output:
# CHEEVOS_HMAC_KEY=<key>          ← store this; use for: CHEEVOS_HMAC_KEY=<key> make dist-zip
# LEADERBOARD_SECRET=<blob>       ← distribute to users
```

**Mode 3 — leaderboard secret only** (existing binary, no rebuild needed):
```bash
cd go && CHEEVOS_HMAC_KEY=<existing-key> go run ./tools/keygen --token <api-token> --api-url <api-url>
# Output:
# LEADERBOARD_SECRET=<blob>       ← distribute to users
```

Run `go run ./go/tools/keygen --help` for the full usage reference.

**Via GitHub Actions:** Use the `Generate Leaderboard Secret` workflow dispatch in the
repo. Supply the token and API URL as inputs — the HMAC key is read from the
`CHEEVOS_HMAC_KEY` repository secret. All sensitive values are masked in logs and the
secret is delivered as a 1-day artifact.

Distribute the blob to users:
```bash
bash install.sh --leaderboard-secret <blob>
```

---

## Adding Custom Achievements

Edit `data/definitions.json` and re-run `install.sh` to deploy. Progress is preserved. Rebuild (`make dist-zip`) only if redistributing to other users.

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

Add `"tutorial": true` to include the achievement in the `/achievements-tutorial` guided tour.

For the full list of counters, condition types, and hook extension patterns,
see [`.claude/CLAUDE.md`](.claude/CLAUDE.md).

---

## Bash 3.2 Constraints (macOS)

macOS ships with Bash 3.2. All scripts must be compatible. Key restrictions:

| Feature | Bash 4+ only | Bash 3.2 alternative |
|---|---|---|
| `declare -A` | Yes | `case` or newline-delimited strings with `grep -qx` |
| `${var^^}` | Yes | `tr '[:lower:]' '[:upper:]'` or `grep -qi` |
| `mapfile` / `readarray` | Yes | `while IFS= read -r line; do ... done < <(...)` |
| Literal `'` in single-quoted jq strings | N/A | Use `.` or `.?` in regex (e.g. `you.?re` not `you'?re`) |

**Quoting pitfall:** jq expressions in `stop.sh` span 60+ lines inside single quotes. A stray
`'` breaks the quoting silently — bash reports `unexpected EOF` at the *end* of the file.
Always run `bash -n script.sh` after editing any hook.
