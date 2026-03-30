package subcmd

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"

    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/store"
)

// Verify checks that the binary installation is healthy and prints a summary.
func Verify(achievementsDir string) error {
    settings := os.Getenv("HOME") + "/.claude/settings.json"
    ok := true

    fmt.Println("Claude Cheevos Installation Verification")
    fmt.Println("==========================================")
    fmt.Println()

    // Binary itself.
    binary := filepath.Join(achievementsDir, "cheevos")
    if info, err := os.Stat(binary); err != nil || info.Mode()&0111 == 0 {
        fmt.Println("✗ cheevos binary not found or not executable:", binary)
        ok = false
    } else {
        fmt.Println("✓ cheevos binary present")
    }

    // Encryption key.
    keyFile := filepath.Join(achievementsDir, ".key")
    if _, err := os.Stat(keyFile); err != nil {
        fmt.Println("✗ Encryption key missing (.key) — run: cheevos init")
        ok = false
    } else {
        fmt.Println("✓ Encryption key present")
    }

    // Encrypted state readable.
    stateFile := filepath.Join(achievementsDir, "state.json")
    key, keyErr := crypto.LoadKeyFromFile(achievementsDir)
    if keyErr == nil {
        if st, err := store.NewEncryptedJSONStore(stateFile, key).Load(); err != nil {
            fmt.Println("✗ State file unreadable:", err)
            ok = false
        } else {
            fmt.Printf("✓ State readable (score: %d pts, %d unlocked)\n", st.Score, len(st.Unlocked))
        }
    }

    // notifications.json valid JSON.
    notifFile := filepath.Join(achievementsDir, "notifications.json")
    if data, err := os.ReadFile(notifFile); err != nil {
        fmt.Println("✗ notifications.json missing")
        ok = false
    } else if !json.Valid(data) {
        fmt.Println("✗ notifications.json is not valid JSON")
        ok = false
    } else {
        fmt.Println("✓ notifications.json valid")
    }

    // hooks registered in settings.json.
    if data, err := os.ReadFile(settings); err != nil {
        fmt.Println("⚠  settings.json not found:", settings)
    } else {
        var cfg map[string]json.RawMessage
        if json.Unmarshal(data, &cfg) == nil {
            var hooks map[string]json.RawMessage
            if hraw, ok2 := cfg["hooks"]; ok2 {
                json.Unmarshal(hraw, &hooks)
            }
            registered := 0
            for _, name := range []string{"SessionStart", "PostToolUse", "Stop", "PreCompact"} {
                if _, found := hooks[name]; found {
                    registered++
                } else {
                    fmt.Printf("⚠  Hook not registered: %s\n", name)
                }
            }
            if registered == 4 {
                fmt.Println("✓ All 4 hooks registered in settings.json")
            }

            // statusLine check.
            var statusLineCfg struct {
                Command string `json:"command"`
            }
            if slRaw, ok2 := cfg["statusLine"]; ok2 {
                json.Unmarshal(slRaw, &statusLineCfg)
            }
            if statusLineCfg.Command != "" {
                fmt.Printf("✓ statusLine configured: %s\n", statusLineCfg.Command)
            } else {
                fmt.Println("⚠  statusLine not configured — score won't show in status bar")
            }
        }
    }

    fmt.Println()
    if ok {
        fmt.Println("✓ Installation verified successfully!")
    } else {
        fmt.Println("✗ Some checks failed — consider re-running install.sh")
        return fmt.Errorf("verification failed")
    }
    return nil
}
