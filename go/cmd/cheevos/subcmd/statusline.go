package subcmd

import (
    "fmt"
    "io"
    "os"
    "os/exec"
    "path/filepath"
    "strings"

    "github.com/user/claude-cheevos/internal/store"
)

// Statusline renders the achievement score for the Claude Code status bar.
// Reads from stdin (the JSON blob Claude Code passes to statusLine.command),
// then outputs: [original-output " | "] "🏆 N pts"
func Statusline(achievementsDir string, key [32]byte) error {
    // Buffer stdin — may be forwarded to the original command.
    input, _ := io.ReadAll(os.Stdin)

    segment, err := buildSegment(achievementsDir, key)
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

func buildSegment(achievementsDir string, key [32]byte) (string, error) {
    stateFile := filepath.Join(achievementsDir, "state.json")
    st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
    if err != nil {
        return fmt.Sprintf("🏆 0 pts"), nil //nolint:nilerr
    }

    return fmt.Sprintf("🏆 %d pts", st.Score), nil
}
