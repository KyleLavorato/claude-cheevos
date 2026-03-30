package subcmd

import (
    "encoding/json"
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
    "time"

    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/engine"
    "github.com/user/claude-cheevos/internal/lock"
    "github.com/user/claude-cheevos/internal/notify"
    "github.com/user/claude-cheevos/internal/store"
)

// Drain atomically empties the notification queue, fires OS notifications,
// and emits a {"systemMessage": "..."} JSON blob to stdout for Claude Code.
func Drain(achievementsDir string) error {
    notifFile := filepath.Join(achievementsDir, "notifications.json")
    lockFile := filepath.Join(achievementsDir, "state.lock")

    if _, err := os.Stat(notifFile); os.IsNotExist(err) {
        return nil // nothing to drain
    }

    // Drain queue under lock.
    var drained []engine.Notification
    l := lock.New(lockFile)
    if err := l.Lock(5 * time.Second); err != nil {
        return err
    }
    func() {
        defer l.Unlock()

        data, err := os.ReadFile(notifFile)
        if err != nil || string(data) == "[]" || string(data) == "" {
            return
        }
        if err := json.Unmarshal(data, &drained); err != nil || len(drained) == 0 {
            drained = nil
            return
        }
        // Reset queue atomically.
        tmp, err := os.CreateTemp(filepath.Dir(notifFile), ".notif_drain_")
        if err != nil {
            return
        }
        tmpName := tmp.Name()
        tmp.Write([]byte("[]"))
        tmp.Close()
        os.Rename(tmpName, notifFile) //nolint:errcheck
    }()

    if len(drained) == 0 {
        return nil
    }

    // Read current score (display-only, no lock needed).
    score := 0
    key, err := crypto.LoadKeyFromFile(achievementsDir)
    if err == nil {
        stateFile := filepath.Join(achievementsDir, "state.json")
        if st, err := store.NewEncryptedJSONStore(stateFile, key).Load(); err == nil {
            score = st.Score
        }
    }

    // Build achievement lines.
    var lines []string
    for _, n := range drained {
        lines = append(lines, fmt.Sprintf("  [%s +%d pts] %s", n.Name, n.Points, n.Description))
    }

    // Fire OS notification.
    var notifTitle, notifBody string
    if len(drained) == 1 {
        notifTitle = "🏆 Achievement Unlocked!"
        notifBody = fmt.Sprintf("%s (+%d pts)", drained[0].Description, drained[0].Points)
    } else {
        names := make([]string, len(drained))
        for i, n := range drained {
            names[i] = n.Name
        }
        notifTitle = fmt.Sprintf("🏆 %d Achievements Unlocked!", len(drained))
        notifBody = strings.Join(names, ", ")
    }
    _ = notify.Send(notifTitle, notifBody) // best-effort; ignore error

    // Emit systemMessage JSON to stdout for Claude Code to display inline.
    header := "🏆 Achievement Unlocked!"
    if len(drained) > 1 {
        header = fmt.Sprintf("🏆 %d Achievements Unlocked!", len(drained))
    }
    msg := header + "\n" + strings.Join(lines, "\n") + fmt.Sprintf("\nTotal Score: %d pts", score)

    out := map[string]string{"systemMessage": msg}
    data, _ := json.Marshal(out)
    fmt.Println(string(data))

    // Achievements were unlocked — sync score to leaderboard in the background.
    // We spawn a new process rather than calling LeaderboardSync() directly so
    // that Drain returns immediately (no HTTP latency in the stop hook).
    if exe, err := os.Executable(); err == nil {
        cmd := exec.Command(exe, "leaderboard-sync")
        cmd.Env = append(os.Environ(), "ACHIEVEMENTS_DIR="+achievementsDir)
        _ = cmd.Start() // fire-and-forget; ignore error
    }

    return nil
}
