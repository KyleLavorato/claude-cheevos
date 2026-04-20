Disable automatic daily update checks for the Claude Code Achievement System.
This creates a `.no-auto-update` flag file that prevents the system from fetching
updates from GitHub on session start.

Use the Bash tool to run:

```bash
touch ~/.claude/achievements/.no-auto-update
```

Then tell the user: "Auto-updates are now disabled. The system will no longer check for
updates on session start. You can still update manually at any time using /achievements-update,
or re-enable auto-updates using /achievements-enable-update."
