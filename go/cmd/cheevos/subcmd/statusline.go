package subcmd

import (
    "fmt"
    "io"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
    "time"

    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/defs"
    "github.com/user/claude-cheevos/internal/store"
)

// Statusline renders the achievement score for the Claude Code status bar.
// Reads from stdin (the JSON blob Claude Code passes to statusLine.command),
// then outputs: [original-output " | "] "🏆 N pts[ (Name!)]"
func Statusline(achievementsDir string) error {
    // Buffer stdin — may be forwarded to the original command.
    input, _ := io.ReadAll(os.Stdin)

    segment, err := buildSegment(achievementsDir)
    if err != nil {
        // Degrade gracefully — show minimal output rather than failing.
        fmt.Print("🏆 ? pts")
        return nil
    }

    // Call original statusLine command if saved at install time.
    originalSave := filepath.Join(achievementsDir, ".original-statusline")
    originalOutput := ""
    if origCmdBytes, err := os.ReadFile(originalSave); err == nil {
        origCmd := strings.TrimSpace(string(origCmdBytes))
        if origCmd != "" {
            cmd := exec.Command("sh", "-c", origCmd)
            cmd.Stdin = strings.NewReader(string(input))
            if out, err := cmd.Output(); err == nil {
                originalOutput = strings.TrimRight(string(out), "\n")
            }
        }
    }

    if originalOutput != "" {
        fmt.Printf("%s | %s", originalOutput, segment)
    } else {
        fmt.Print(segment)
    }
    return nil
}

func buildSegment(achievementsDir string) (string, error) {
    key, err := crypto.LoadKeyFromFile(achievementsDir)
    if err != nil {
        return "🏆 0 pts", nil //nolint:nilerr — degrade gracefully
    }

    stateFile := filepath.Join(achievementsDir, "state.json")
    st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
    if err != nil {
        return fmt.Sprintf("🏆 0 pts"), nil //nolint:nilerr
    }

    score := st.Score

    // Show most recently unlocked achievement name for 5 minutes after unlock.
    if st.LastUpdated != "" && len(st.Unlocked) > 0 {
        lastUpdated, err := time.Parse(time.RFC3339, st.LastUpdated)
        if err == nil && time.Since(lastUpdated) < 5*time.Minute {
            lastID := st.Unlocked[len(st.Unlocked)-1]
            d, derr := defs.Load(achievementsDir)
            if derr == nil {
                if ach := d.ByID(lastID); ach != nil {
                    return fmt.Sprintf("🏆 %d pts (%s!)", score, ach.Name), nil
                }
            }
        }
    }

    return fmt.Sprintf("🏆 %d pts", score), nil
}
