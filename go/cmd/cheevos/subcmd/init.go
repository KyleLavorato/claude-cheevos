package subcmd

import (
    "crypto/rand"
    "encoding/base64"
    "fmt"
    "os"
    "path/filepath"
)

// Init creates the achievements directory, encryption key file, and
// notifications.json if they don't already exist. Safe to call multiple
// times (idempotent). State creation is left to cheevos seed.
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
        fmt.Println("✓ Encryption key generated")
    } else {
        fmt.Println("✓ Encryption key preserved")
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

