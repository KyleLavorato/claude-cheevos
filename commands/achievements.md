Launch the Claude Code Achievement System web browser and return immediately.

Use the Bash tool to run:

```bash
BINARY="$HOME/.claude/achievements/cheevos"
if [[ -f "$BINARY" ]]; then
  nohup "$BINARY" serve > /tmp/cheevos-serve.log 2>&1 &
  sleep 0.4
  echo "LAUNCHED"
else
  echo "BINARY_NOT_FOUND"
fi
```

**If the output is "BINARY_NOT_FOUND":**
Tell the user the cheevos binary isn't installed yet. They need to download and install from the [latest release](https://github.com/KyleLavorato/claude-cheevos/releases/latest).

**If the output is "LAUNCHED":**
Reply with a single short line telling the user the browser opened (or is opening) and they can close the tab when done. Do not wait for any further output. Do not run any more commands.
