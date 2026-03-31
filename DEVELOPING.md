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
| `make clean` | Remove `dist/` and the embedded defs copy |

> **HMAC key:** Each build generates a fresh random key baked into the binary. The installer
> reads it back via `cheevos print-hmac-secret` — you don't need to store the key yourself.
> To keep a consistent key across builds, prefix with `CHEEVOS_HMAC_KEY=$(cd go && go run ./tools/keygen)`.

---

## Adding Custom Achievements

Edit `data/definitions.json`, rebuild (`make dist`), and re-run `install.sh`. Progress is preserved.

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

Add `"tutorial": true` to include the achievement in `cheevos learn`.

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
