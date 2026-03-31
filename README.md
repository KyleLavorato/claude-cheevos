# claude-cheevos - Claude Code Achievement System

![](docs/banner.png)

A self-contained achievement system for [Claude Code](https://claude.ai/code) that tracks your
usage milestones, awards points, and surfaces progress through a live status bar and achievement browser.

---

## Contents

[Requirements](#requirements) · [Installation](#installation) · [Slash Commands](#slash-commands) · [Tutorial](#tutorial) · [Achievement List](#achievement-list) · [Notifications](#notifications) · [Auto-Updates](#auto-updates) · [Leaderboard](#leaderboard) · [Uninstallation](#uninstallation) · [Contributing](#contributing)

---

## Requirements

- [Claude Code](https://claude.ai/code) installed (`~/.claude/settings.json` must exist)
- `bash` 3.2+ and `jq` 1.6+
- macOS, Linux, or Windows (via WSL)

---

## Installation

1. Download the zip for your platform from the [latest release](https://github.com/KyleLavorato/claude-cheevos/releases/latest):

   | Platform | File |
   |---|---|
   | macOS Apple Silicon | `claude-cheevos-darwin-arm64.zip` |
   | macOS Intel | `claude-cheevos-darwin-amd64.zip` |
   | Linux ARM64 | `claude-cheevos-linux-arm64.zip` |
   | Linux x86_64 | `claude-cheevos-linux-amd64.zip` |
   | Windows (WSL) | `claude-cheevos-windows-amd64.zip` |

2. Unzip and run the installer:

   ```bash
   unzip claude-cheevos-<platform>.zip
   bash install.sh
   ```

3. **Restart Claude Code** for hooks to take effect.

After install, your status bar shows `🏆 560 pts` at all times. If you had an existing
`statusLine` command it is preserved — cheevos appends to it.

The installer is **idempotent** — safe to re-run to upgrade. Your score and progress are never touched.

**Optional:** Enable leaderboard sync:

```bash
bash install.sh --token <api-token> --api-url https://...execute-api.../prod
```

**Verify the install:**

```bash
~/.claude/achievements/cheevos verify
```

---

## Slash Commands

Two commands are available inside Claude Code immediately after installation:

- `/achievements` — opens the achievement browser in your default browser
- `/uninstall-achievements` — interactive uninstall flow inside Claude Code

---

## Tutorial

A guided walkthrough of the 8 core beginner achievements with tips and a progress bar.

```bash
~/.claude/achievements/cheevos learn
```

```
🗺️   Claude Cheevos — Tutorial
3/8 complete  ·  [████████░░░░░░░░░░░░]  60/165 pts

⭐  Up Next
────────────────────────────────────────────────────────────
  ⭐  Code Sculptor              +20 pts  [3/10 files_written]
      Write 10 files with Claude
      💡 Ask Claude to create files: 'Create a utils.py with a helper function'
```

Completing all 8 unlocks the **Graduate** rank badge.

---

## Achievement List

Use `/achievements` in Claude Code to open the achievement browser — filter by status and
skill level, search by name, and track progress bars for locked achievements.

For the full list of achievements, categories, and skill levels, see [docs/achievement_list.md](docs/achievement_list.md).

---

## Notifications

When an achievement unlocks you get an inline system message inside Claude Code and a native
desktop notification (macOS notification center with Glass sound; PowerShell Toast on Windows).

```
🏆 Achievement Unlocked!
  [Power User +150 pts] Complete 100 Claude Code sessions
Total Score: 710 pts
```

Multiple unlocks in the same turn are batched into one notification.

---

## Auto-Updates

New achievements are automatically downloaded from the public GitHub repo once per day on
session start. Your progress is always preserved.

```bash
# Force an immediate check
~/.claude/achievements/cheevos update-defs --force
```

To disable, remove the `cheevos update-defs &` line from
`~/.claude/achievements/hooks/session-start.sh`.

---

## Leaderboard

An optional live leaderboard lets you compare scores with teammates. See
[microservice/README.md](microservice/README.md) for deployment and setup instructions.

---

## Uninstallation

Use `/uninstall-achievements` inside Claude Code. It removes hooks, optionally deletes
state, and restores your original status line.

---

## Contributing

See [DEVELOPING.md](DEVELOPING.md) for build instructions, adding custom achievements, and
Bash 3.2 compatibility notes.

For how achievements are tracked internally, see
[docs/how-achievements-are-tracked.md](docs/how-achievements-are-tracked.md).
