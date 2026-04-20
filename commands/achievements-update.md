Force an immediate update check for the Claude Code Achievement System, downloading the
latest achievement definitions, binary, and hook scripts from GitHub.

Use the Bash tool to run:

```bash
~/.claude/achievements/cheevos check-updates --force
```

Display the output to the user verbatim. If the command reports that everything is already
up to date, tell the user they are running the latest version. If it reports that an update
was applied, tell the user to restart Claude Code for the changes to take effect.
