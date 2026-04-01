package main

import (
    "fmt"
    "os"

    "github.com/user/claude-cheevos/cmd/cheevos/subcmd"
    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/selfpatch"
)

// hmacSecretRaw is injected at compile time by:
//   go build -ldflags "-X 'main.hmacSecretRaw=<xor-obfuscated-base64>'"
// It is the HMAC secret XOR'd with the obfuscation nonce defined in internal/crypto/key.go.
// Never log or print this variable directly.
var hmacSecretRaw string

// appVersion is injected at compile time via -ldflags
// Defaults to "dev" if not injected
var appVersion = "dev"

func main() {
    if len(os.Args) < 2 {
        usage()
        os.Exit(1)
    }

    // Decode HMAC secret and derive the AES state key from it.
    // Both are deterministic from the compile-time secret — no key file needed.
    hmacSecret, _ := crypto.DeobfuscateHMACKey(hmacSecretRaw)
    stateKey, _ := crypto.DeriveStateKey(hmacSecret)

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

    // Self-patch lib.sh with correct HMAC secret (best-effort).
    selfpatch.EnsureLibShSecret(achievementsDir, hmacSecret)

    cmd := os.Args[1]
    args := os.Args[2:]

    var err error
    switch cmd {
    case "version":
        err = subcmd.Version(appVersion)
    case "update":
        err = subcmd.Update(achievementsDir, hmacSecret, stateKey)
    case "init":
        err = subcmd.Init(achievementsDir)
    case "seed":
        err = subcmd.Seed(achievementsDir, args, stateKey)
    case "statusline":
        err = subcmd.Statusline(achievementsDir, stateKey)
    case "show":
        err = subcmd.Show(achievementsDir, args, stateKey)
    case "award":
        err = subcmd.Award(achievementsDir, args, stateKey)
    case "drain":
        err = subcmd.Drain(achievementsDir, stateKey)
    case "update-defs":
        force := len(args) > 0 && args[0] == "--force"
        err = subcmd.UpdateDefs(achievementsDir, force, stateKey)
    case "update-binary":
        force := len(args) > 0 && args[0] == "--force"
        err = subcmd.UpdateBinary(achievementsDir, appVersion, force, stateKey)
    case "check-updates":
        force := len(args) > 0 && args[0] == "--force"
        err = subcmd.CheckUpdates(achievementsDir, appVersion, force, stateKey)
    case "serve":
        err = subcmd.Serve(achievementsDir, stateKey)
    case "leaderboard-sync":
        err = subcmd.LeaderboardSync(achievementsDir, stateKey)
    case "leaderboard-delete":
        err = subcmd.LeaderboardDelete(achievementsDir, stateKey)
    case "get-counter":
        err = subcmd.GetCounter(achievementsDir, args, stateKey)
    case "verify":
        err = subcmd.Verify(achievementsDir, stateKey)
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
  version             Print the application version
  update              Apply counter updates from hook env vars (requires HMAC)
  init                Create initial state and key files (idempotent)
  seed <cache>        Pre-unlock achievements based on existing session count
  statusline          Render achievement score for the status bar
  show [flags]        List achievements (--unlocked, --locked, --beginner, ...)
  award <counter>     Manually increment a counter (Easter eggs)
  drain               Drain notification queue and emit systemMessage
  serve               Open achievement browser web UI in the system browser
  update-defs [--force]     Fetch new achievement definitions from GitHub (once/day)
  update-binary [--force]   Update the cheevos binary from GitHub releases (once/day)
  check-updates [--force]   Check for both definition and binary updates
  leaderboard-sync    Push score to leaderboard API (reads leaderboard.conf)
  leaderboard-delete  Remove user entry from leaderboard API (used by uninstall)
  get-counter <name>  Print the current value of a named counter
  verify              Verify the installation is healthy
  print-hmac-secret   Print HMAC secret (hex) for install.sh`)
}
