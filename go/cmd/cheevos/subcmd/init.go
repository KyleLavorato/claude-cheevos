package subcmd

import (
    "crypto/rand"
    "encoding/base64"
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"

    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/store"
)

// Init creates the achievements directory structure, encryption key file,
// notifications.json, and initial state if they don't already exist.
// Safe to call multiple times (idempotent).
func Init(achievementsDir string) error {
    if err := os.MkdirAll(achievementsDir, 0700); err != nil {
        return fmt.Errorf("init: mkdir %s: %w", achievementsDir, err)
    }

    // Generate encryption key on first install.
    keyFile := filepath.Join(achievementsDir, ".key")
    if _, err := os.Stat(keyFile); os.IsNotExist(err) {
        raw := make([]byte, 32)
        if _, err := rand.Read(raw); err != nil {
            return fmt.Errorf("init: generate key: %w", err)
        }
        encoded := base64.StdEncoding.EncodeToString(raw)
        if err := os.WriteFile(keyFile, []byte(encoded+"\n"), 0600); err != nil {
            return fmt.Errorf("init: write .key: %w", err)
        }
    }

    // Create empty notification queue.
    notifFile := filepath.Join(achievementsDir, "notifications.json")
    if _, err := os.Stat(notifFile); os.IsNotExist(err) {
        if err := os.WriteFile(notifFile, []byte("[]"), 0600); err != nil {
            return fmt.Errorf("init: create notifications.json: %w", err)
        }
    }

    // Create initial encrypted state.
    stateFile := filepath.Join(achievementsDir, "state.json")
    if _, err := os.Stat(stateFile); os.IsNotExist(err) {
        key, err := crypto.LoadKeyFromFile(achievementsDir)
        if err != nil {
            return err
        }
        st := store.NewState()
        if err := store.NewEncryptedJSONStore(stateFile, key).Save(st); err != nil {
            return fmt.Errorf("init: create state: %w", err)
        }
    }

    return nil
}

// readNotifications reads the current notification queue from disk.
func readNotifications(path string) ([]json.RawMessage, error) {
    data, err := os.ReadFile(path)
    if os.IsNotExist(err) {
        return nil, nil
    }
    if err != nil {
        return nil, err
    }
    var msgs []json.RawMessage
    if err := json.Unmarshal(data, &msgs); err != nil {
        return nil, err
    }
    return msgs, nil
}
