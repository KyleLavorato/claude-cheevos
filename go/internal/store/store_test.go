package store

import (
    "encoding/json"
    "os"
    "path/filepath"
    "testing"
)

func testKey() [32]byte {
    var k [32]byte
    copy(k[:], "store-test-key-32-bytes-exactly!")
    return k
}

func TestEncryptedJSONStoreRoundTrip(t *testing.T) {
    dir := t.TempDir()
    path := filepath.Join(dir, "state.json")
    key := testKey()

    s := NewEncryptedJSONStore(path, key)

    st := NewState()
    st.Score = 42
    st.Counters["sessions"] = 7
    st.Unlocked = append(st.Unlocked, "first_session")

    if err := s.Save(st); err != nil {
        t.Fatalf("Save: %v", err)
    }
    if !s.Exists() {
        t.Fatal("Exists() should return true after Save")
    }

    loaded, err := s.Load()
    if err != nil {
        t.Fatalf("Load: %v", err)
    }
    if loaded.Score != 42 {
        t.Errorf("Score: got %d want 42", loaded.Score)
    }
    if loaded.Counters["sessions"] != 7 {
        t.Errorf("sessions counter: got %d want 7", loaded.Counters["sessions"])
    }
    if len(loaded.Unlocked) != 1 || loaded.Unlocked[0] != "first_session" {
        t.Errorf("Unlocked: got %v", loaded.Unlocked)
    }
}

func TestLoadMissingReturnsDefault(t *testing.T) {
    dir := t.TempDir()
    path := filepath.Join(dir, "state.json")
    key := testKey()

    s := NewEncryptedJSONStore(path, key)
    st, err := s.Load()
    if err != nil {
        t.Fatalf("Load of missing file: %v", err)
    }
    if st.Score != 0 || st.SchemaVersion != 1 {
        t.Errorf("unexpected default state: %+v", st)
    }
}

func TestPlaintextMigration(t *testing.T) {
    dir := t.TempDir()
    path := filepath.Join(dir, "state.json")
    key := testKey()

    // Write a legacy plaintext state.json.
    legacy := NewState()
    legacy.Score = 99
    legacy.Counters["bash_calls"] = 3
    data, _ := json.Marshal(legacy)
    os.WriteFile(path, data, 0600)

    s := NewEncryptedJSONStore(path, key)
    loaded, err := s.Load()
    if err != nil {
        t.Fatalf("Load of plaintext: %v", err)
    }
    if loaded.Score != 99 {
        t.Errorf("Score after migration: got %d want 99", loaded.Score)
    }

    // Backup should exist.
    if _, err := os.Stat(path + ".bak"); os.IsNotExist(err) {
        t.Error("expected .bak file after migration")
    }

    // File should now be encrypted (not readable as plain JSON).
    raw, _ := os.ReadFile(path)
    var check State
    if json.Unmarshal(raw, &check) == nil && check.Score == 99 {
        t.Error("state.json should be encrypted after migration, not plaintext")
    }

    // Second load should succeed (encrypted path).
    loaded2, err := s.Load()
    if err != nil {
        t.Fatalf("second Load: %v", err)
    }
    if loaded2.Score != 99 {
        t.Errorf("Score on second load: got %d want 99", loaded2.Score)
    }
}

func TestAtomicSave(t *testing.T) {
    dir := t.TempDir()
    path := filepath.Join(dir, "state.json")
    key := testKey()
    s := NewEncryptedJSONStore(path, key)

    st := NewState()
    st.Score = 1
    if err := s.Save(st); err != nil {
        t.Fatalf("first Save: %v", err)
    }

    st.Score = 2
    if err := s.Save(st); err != nil {
        t.Fatalf("second Save: %v", err)
    }

    loaded, _ := s.Load()
    if loaded.Score != 2 {
        t.Errorf("expected score 2 after second Save, got %d", loaded.Score)
    }

    // No temp files should remain.
    entries, _ := os.ReadDir(dir)
    for _, e := range entries {
        if e.Name() != "state.json" {
            t.Errorf("unexpected file in dir: %s", e.Name())
        }
    }
}
