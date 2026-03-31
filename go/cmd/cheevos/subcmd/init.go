package subcmd

import (
    "fmt"
    "os"
    "path/filepath"
)

// Init creates the achievements directory and notifications.json if they don't
// already exist. Safe to call multiple times (idempotent).
// The AES key is no longer stored on disk — it is derived from the binary's
// compile-time HMAC secret via DeriveStateKey.
func Init(achievementsDir string) error {
    if err := os.MkdirAll(achievementsDir, 0700); err != nil {
        return fmt.Errorf("init: mkdir %s: %w", achievementsDir, err)
    }

    // Create empty notification queue.
    notifFile := filepath.Join(achievementsDir, "notifications.json")
    if _, err := os.Stat(notifFile); os.IsNotExist(err) {
        if err := os.WriteFile(notifFile, []byte("[]"), 0600); err != nil {
            return fmt.Errorf("init: create notifications.json: %w", err)
        }
        fmt.Println("✓ Notifications queue created")
    }

    return nil
}
