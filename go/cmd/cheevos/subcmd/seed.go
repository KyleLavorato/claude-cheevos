package subcmd

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "time"

    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/defs"
    "github.com/user/claude-cheevos/internal/store"
)

// Seed creates the initial encrypted state seeded from existing Claude Code stats.
// It only runs on first install (when state.json does not yet exist).
// args[0] (optional) is the path to stats-cache.json.
func Seed(achievementsDir string, args []string) error {
    stateFile := filepath.Join(achievementsDir, "state.json")

    // Skip if state already exists (upgrade path — preserve existing state).
    if _, err := os.Stat(stateFile); err == nil {
        fmt.Println("cheevos seed: state already exists, skipping")
        return nil
    }

    statsCachePath := os.Getenv("HOME") + "/.claude/stats-cache.json"
    if len(args) > 0 {
        statsCachePath = args[0]
    }

    // Read totalSessions from stats-cache.json.
    totalSessions := int64(0)
    if data, err := os.ReadFile(statsCachePath); err == nil {
        var cache struct {
            TotalSessions int64 `json:"totalSessions"`
        }
        if json.Unmarshal(data, &cache) == nil {
            totalSessions = cache.TotalSessions
        }
        fmt.Printf("cheevos seed: found %d existing sessions\n", totalSessions)
    } else {
        fmt.Println("cheevos seed: no stats-cache.json found, starting fresh")
    }

    // Load definitions.
    d, err := defs.Load(achievementsDir)
    if err != nil {
        return err
    }

    // Find session-based achievements already earned.
    st := store.NewState()
    st.Counters["sessions"] = totalSessions
    now := time.Now().UTC().Format(time.RFC3339)
    st.LastUpdated = now

    for _, ach := range d.Achievements {
        cond := ach.Condition
        condType := cond.Type
        if condType == "" {
            condType = "counter"
        }
        if condType == "counter" && cond.Counter == "sessions" && totalSessions >= cond.Threshold {
            st.Unlocked = append(st.Unlocked, ach.ID)
            st.Score += ach.Points
            if st.UnlockTimes == nil {
                st.UnlockTimes = make(map[string]string)
            }
            st.UnlockTimes[ach.ID] = now
        }
    }

    // Save encrypted state.
    key, err := crypto.LoadKeyFromFile(achievementsDir)
    if err != nil {
        return err
    }
    if err := store.NewEncryptedJSONStore(stateFile, key).Save(st); err != nil {
        return fmt.Errorf("seed: save state: %w", err)
    }

    // Ensure notifications file exists.
    notifFile := filepath.Join(achievementsDir, "notifications.json")
    if _, err := os.Stat(notifFile); os.IsNotExist(err) {
        _ = os.WriteFile(notifFile, []byte("[]"), 0600)
    }

    fmt.Printf("cheevos seed: %d achievements pre-unlocked, score: %d pts\n",
        len(st.Unlocked), st.Score)
    return nil
}
