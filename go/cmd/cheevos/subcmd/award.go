package subcmd

import (
    "fmt"
    "path/filepath"
    "time"

    "github.com/user/claude-cheevos/internal/defs"
    "github.com/user/claude-cheevos/internal/engine"
    "github.com/user/claude-cheevos/internal/lock"
    "github.com/user/claude-cheevos/internal/store"
)

// Award manually increments a named counter by 1.
// Used for Easter egg achievements (e.g. award easter_egg_unlocks).
func Award(achievementsDir string, args []string, key [32]byte) error {
    if len(args) == 0 {
        return fmt.Errorf("award: counter name required")
    }
    counter := args[0]

    stateFile := filepath.Join(achievementsDir, "state.json")
    notifFile := filepath.Join(achievementsDir, "notifications.json")
    lockFile := filepath.Join(achievementsDir, "state.lock")

    l := lock.New(lockFile)
    if err := l.Lock(5 * time.Second); err != nil {
        return err
    }
    defer l.Unlock()

    storeInst := store.NewEncryptedJSONStore(stateFile, key)
    st, err := storeInst.Load()
    if err != nil {
        return fmt.Errorf("award: load state: %w", err)
    }

    d, err := defs.Load(achievementsDir)
    if err != nil {
        return err
    }

    // Only the easter_egg_unlocks counter may be awarded manually.
    // All other counters are tracked automatically by hooks; awarding them
    // directly would bypass the achievement system and constitute cheating.
    if counter != "easter_egg_unlocks" {
        return fmt.Errorf("award: only \"easter_egg_unlocks\" may be awarded manually\n       Other counters are tracked automatically by hooks")
    }

    params := engine.UpdateParams{
        CounterUpdates: map[string]int64{counter: 1},
    }
    newly, err := engine.Update(st, d, params)
    if err != nil {
        return fmt.Errorf("award: engine: %w", err)
    }

    if err := storeInst.Save(st); err != nil {
        return fmt.Errorf("award: save state: %w", err)
    }

    if len(newly) > 0 {
        if err := engine.AppendNotifications(notifFile, newly); err != nil {
            return fmt.Errorf("award: append notifications: %w", err)
        }
        for _, n := range newly {
            fmt.Printf("🏆 Achievement Unlocked: %s (+%d pts)\n", n.Name, n.Points)
        }
    }

    fmt.Printf("Awarded: %s (now %d)\n", counter, st.Counters[counter])
    return nil
}
