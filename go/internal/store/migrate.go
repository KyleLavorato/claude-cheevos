package store

import (
    "encoding/json"
    "fmt"
    "os"
)

// migratePlaintext attempts to parse data as a legacy plaintext State JSON.
// If successful, it re-saves it in encrypted form (migrating the file in-place)
// and renames the original to state.json.bak as a backup.
func migratePlaintext(s *EncryptedJSONStore, data []byte) (*State, error) {
    var st State
    if err := json.Unmarshal(data, &st); err != nil {
        return nil, fmt.Errorf("store: file is neither encrypted envelope nor valid plaintext JSON: %w", err)
    }

    // Back up the original plaintext file.
    bakPath := s.Path + ".bak"
    _ = os.WriteFile(bakPath, data, 0600) // best-effort; ignore error

    // Save in encrypted format.
    if err := s.Save(&st); err != nil {
        return nil, fmt.Errorf("store: migration failed (could not encrypt): %w", err)
    }

    fmt.Fprintf(os.Stderr, "cheevos: migrated plaintext state to encrypted format (backup at %s)\n", bakPath)
    return &st, nil
}
