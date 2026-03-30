package subcmd

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "time"

    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/defs"
    "github.com/user/claude-cheevos/internal/engine"
    cheevosmac "github.com/user/claude-cheevos/internal/hmac"
    "github.com/user/claude-cheevos/internal/lock"
    "github.com/user/claude-cheevos/internal/store"
)

// Update applies counter increments from hook env vars to the encrypted state.
// Requires a valid HMAC signature (_CHEEVOS_SIG) unless hmacSecret is empty
// (empty = HMAC disabled, e.g. dev build with no injected key).
func Update(achievementsDir string, hmacSecret []byte) error {
    // Read env vars.
    counterUpdatesJSON := os.Getenv("_COUNTER_UPDATES")
    counterSetsJSON := os.Getenv("_COUNTER_SETS")
    newModel := os.Getenv("_NEW_MODEL")
    sessionID := os.Getenv("_SESSION_ID")
    ts := os.Getenv("_CHEEVOS_TS")
    sig := os.Getenv("_CHEEVOS_SIG")

    if counterUpdatesJSON == "" {
        return fmt.Errorf("update: _COUNTER_UPDATES is required")
    }

    // Verify HMAC (skip if secret not injected — dev builds).
    if len(hmacSecret) > 0 {
        if err := cheevosmac.Verify(hmacSecret, counterUpdatesJSON, counterSetsJSON, newModel, sessionID, ts, sig); err != nil {
            return fmt.Errorf("update: HMAC validation failed: %w", err)
        }
    }

    // Parse counter updates.
    var rawUpdates map[string]int64
    if err := json.Unmarshal([]byte(counterUpdatesJSON), &rawUpdates); err != nil {
        return fmt.Errorf("update: invalid _COUNTER_UPDATES JSON: %w", err)
    }

    // Parse counter sets.
    var rawSets map[string]int64
    if counterSetsJSON != "" {
        if err := json.Unmarshal([]byte(counterSetsJSON), &rawSets); err != nil {
            return fmt.Errorf("update: invalid _COUNTER_SETS JSON: %w", err)
        }
    }

    // Parse optional update-check epoch (_UPDATE_CHECK_EPOCH set by update-defs).
    updateCheckEpoch := int64(0)
    if epochStr := os.Getenv("_UPDATE_CHECK_EPOCH"); epochStr != "" {
        fmt.Sscanf(epochStr, "%d", &updateCheckEpoch)
    }

    params := engine.UpdateParams{
        CounterUpdates:      rawUpdates,
        CounterSets:         rawSets,
        NewModel:            newModel,
        SessionID:           sessionID,
        UpdateCheckEpoch:    updateCheckEpoch,
    }

    // Load encryption key and state store.
    key, err := crypto.LoadKeyFromFile(achievementsDir)
    if err != nil {
        return err
    }
    stateFile := filepath.Join(achievementsDir, "state.json")
    notifFile := filepath.Join(achievementsDir, "notifications.json")
    lockFile := filepath.Join(achievementsDir, "state.lock")

    // Acquire exclusive lock.
    l := lock.New(lockFile)
    if err := l.Lock(5 * time.Second); err != nil {
        return err
    }
    defer l.Unlock()

    st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
    if err != nil {
        return fmt.Errorf("update: load state: %w", err)
    }

    d, err := defs.LoadWithOverride(achievementsDir)
    if err != nil {
        return err
    }

    newly, err := engine.Update(st, d, params)
    if err != nil {
        return fmt.Errorf("update: engine: %w", err)
    }

    if err := store.NewEncryptedJSONStore(stateFile, key).Save(st); err != nil {
        return fmt.Errorf("update: save state: %w", err)
    }

    if len(newly) > 0 {
        if err := engine.AppendNotifications(notifFile, newly); err != nil {
            return fmt.Errorf("update: append notifications: %w", err)
        }
    }

    return nil
}
