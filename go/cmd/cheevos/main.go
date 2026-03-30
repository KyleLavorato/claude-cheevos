package main

import (
    "fmt"
    "os"

    "github.com/user/claude-cheevos/cmd/cheevos/subcmd"
    "github.com/user/claude-cheevos/internal/crypto"
)

// hmacSecretRaw is injected at compile time by:
//   go build -ldflags "-X 'main.hmacSecretRaw=<xor-obfuscated-base64>'"
// It is the HMAC secret XOR'd with the obfuscation nonce defined in internal/crypto/key.go.
// Never log or print this variable directly.
var hmacSecretRaw string

func main() {
    if len(os.Args) < 2 {
        usage()
        os.Exit(1)
    }

    // Decode HMAC secret (available to all subcommands).
    hmacSecret, _ := crypto.DeobfuscateHMACKey(hmacSecretRaw)

    // Resolve achievements directory.
    achievementsDir := os.Getenv("ACHIEVEMENTS_DIR")
    if achievementsDir == "" {
        home, err := os.UserHomeDir()
        if err != nil {
            fmt.Fprintln(os.Stderr, "cheevos: cannot determine home directory:", err)
            os.Exit(1)
        }
        achievementsDir = home + "/.claude/achievements"
    }

    cmd := os.Args[1]
    args := os.Args[2:]

    var err error
    switch cmd {
    case "update":
        err = subcmd.Update(achievementsDir, hmacSecret)
    case "init":
        err = subcmd.Init(achievementsDir)
    case "seed":
        err = subcmd.Seed(achievementsDir, args)
    case "statusline":
        err = subcmd.Statusline(achievementsDir)
    case "show":
        err = subcmd.Show(achievementsDir, args)
    case "learn":
        err = subcmd.Learn(achievementsDir)
    case "award":
        err = subcmd.Award(achievementsDir, args)
    case "drain":
        err = subcmd.Drain(achievementsDir)
    case "update-defs":
        force := len(args) > 0 && args[0] == "--force"
        err = subcmd.UpdateDefs(achievementsDir, force)
    case "serve":
        err = subcmd.Serve(achievementsDir)
    case "leaderboard-sync":
        err = subcmd.LeaderboardSync(achievementsDir)
    case "verify":
        err = subcmd.Verify(achievementsDir)
    case "team-stats":
        err = subcmd.TeamStats(achievementsDir)
    case "print-hmac-secret":
        // Used by install.sh to inject the HMAC secret into lib.sh.
        if len(hmacSecret) == 0 {
            fmt.Fprintln(os.Stderr, "cheevos: HMAC secret not injected at build time")
            os.Exit(1)
        }
        fmt.Printf("%x\n", hmacSecret)
    default:
        fmt.Fprintf(os.Stderr, "cheevos: unknown subcommand %q\n", cmd)
        usage()
        os.Exit(1)
    }

    if err != nil {
        fmt.Fprintln(os.Stderr, "cheevos:", err)
        os.Exit(1)
    }
}

func usage() {
    fmt.Fprintln(os.Stderr, `usage: cheevos <subcommand> [args]

Subcommands:
  update              Apply counter updates from hook env vars (requires HMAC)
  init                Create initial state and key files (idempotent)
  seed <cache>        Pre-unlock achievements based on existing session count
  statusline          Render achievement score for the status bar
  show [flags]        List achievements (--unlocked, --locked, --beginner, ...)
  learn               Show tutorial learning path
  team-stats          Show your contribution to team achievements
  award <counter>     Manually increment a counter (Easter eggs)
  drain               Drain notification queue and emit systemMessage
  serve               Open achievement browser web UI in the system browser
  update-defs [--force]  Fetch new achievement definitions from GitHub (once/day)
  leaderboard-sync    Push score to leaderboard API (reads leaderboard.conf)
  verify              Verify the installation is healthy
  print-hmac-secret   Print HMAC secret (hex) for install.sh`)
}
