Uninstall the Claude Code Achievement System interactively.

## Step 1 — Check leaderboard status

Use the Bash tool to run:

```bash
CONF="$HOME/.claude/achievements/leaderboard.conf"
if [[ -f "$CONF" ]] && grep -q "^LEADERBOARD_ENABLED=true" "$CONF"; then
  USERNAME=$(grep '^USERNAME=' "$CONF" | cut -d= -f2-)
  echo "LEADERBOARD_ACTIVE:${USERNAME}"
else
  echo "LEADERBOARD_INACTIVE"
fi
```

## Step 2 — Confirm with AskUserQuestion

Call AskUserQuestion with **two questions in a single call**.

**Question 1** (header: `"Confirm"`):
- If the Bash output started with `LEADERBOARD_ACTIVE`, use this question text:
  `"Are you sure you want to uninstall the Claude Code Achievement System? ⚠️ You are registered on the leaderboard as [USERNAME] — uninstalling will remove your leaderboard entry."`
- Otherwise use:
  `"Are you sure you want to uninstall the Claude Code Achievement System?"`
- Options:
  - label: `"Yes, uninstall"` — description: `"Removes hooks and slash commands. Your score data is kept."`
  - label: `"Yes, uninstall + delete data"` — description: `"Removes everything including your score history and achievement progress."`
  - label: `"Cancel"` — description: `"Do nothing. Keep the achievement system active."`

**Question 2** (header: `"Heads up"`):
- question: `"Claude Code must be restarted for the uninstall to take full effect."`
- Options:
  - label: `"Got it, proceed"`
  - label: `"Actually, cancel"`

## Step 3 — Act on the answers

**If Question 1 = "Cancel" OR Question 2 = "Actually, cancel":**
Output: "Uninstall cancelled. Your achievement system is still active." — stop here.

**If Question 1 = "Yes, uninstall" AND Question 2 = "Got it, proceed":**
Use the Bash tool to run:
```bash
printf 'n\n' | bash ~/.claude/achievements/uninstall.sh
```

**If Question 1 = "Yes, uninstall + delete data" AND Question 2 = "Got it, proceed":**
Use the Bash tool to run:
```bash
printf 'y\n' | bash ~/.claude/achievements/uninstall.sh
```

After the command completes successfully, tell the user: "Uninstall complete. Please restart Claude Code for the changes to take effect."

If the command fails, show the error output and tell the user they can run the uninstall manually from the repo directory:
```bash
bash uninstall.sh
```
