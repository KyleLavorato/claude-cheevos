package store

import (
    "encoding/base64"
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"

    "github.com/user/claude-cheevos/internal/crypto"
)

// encryptedEnvelope is the on-disk JSON wrapper around the encrypted state.
// "v" is the format version (currently 1).
// "n" is the base64-encoded 12-byte GCM nonce.
// "c" is the base64-encoded AES-256-GCM ciphertext + authentication tag.
type encryptedEnvelope struct {
    V          int    `json:"v"`
    Nonce      string `json:"n"`
    Ciphertext string `json:"c"`
}

// EncryptedJSONStore stores State as an AES-256-GCM encrypted JSON file.
// Each Save generates a fresh random nonce.
type EncryptedJSONStore struct {
    Path string
    key  [32]byte
}

// NewEncryptedJSONStore creates a store backed by the file at path,
// using the given 32-byte AES key.
func NewEncryptedJSONStore(path string, key [32]byte) *EncryptedJSONStore {
    return &EncryptedJSONStore{Path: path, key: key}
}

// Exists reports whether the state file is present on disk.
func (s *EncryptedJSONStore) Exists() bool {
    _, err := os.Stat(s.Path)
    return err == nil
}

// Load reads and decrypts the state file. If the file does not exist, returns
// a fresh default State. If the file is in legacy plaintext format, it is
// transparently migrated to the encrypted format.
func (s *EncryptedJSONStore) Load() (*State, error) {
    data, err := os.ReadFile(s.Path)
    if os.IsNotExist(err) {
        return NewState(), nil
    }
    if err != nil {
        return nil, fmt.Errorf("store: read %s: %w", s.Path, err)
    }

    // Try encrypted envelope first.
    var env encryptedEnvelope
    if jsonErr := json.Unmarshal(data, &env); jsonErr == nil && env.V == 1 && env.Nonce != "" {
        return s.decryptEnvelope(env)
    }

    // Fall back: try legacy plaintext JSON (pre-binary format).
    return migratePlaintext(s, data)
}

func (s *EncryptedJSONStore) decryptEnvelope(env encryptedEnvelope) (*State, error) {
    nonce, err := base64.StdEncoding.DecodeString(env.Nonce)
    if err != nil {
        return nil, fmt.Errorf("store: decode nonce: %w", err)
    }
    ciphertext, err := base64.StdEncoding.DecodeString(env.Ciphertext)
    if err != nil {
        return nil, fmt.Errorf("store: decode ciphertext: %w", err)
    }
    plaintext, err := crypto.Decrypt(s.key, nonce, ciphertext)
    if err != nil {
        return nil, err
    }
    var st State
    if err := json.Unmarshal(plaintext, &st); err != nil {
        return nil, fmt.Errorf("store: unmarshal decrypted state: %w", err)
    }
    return &st, nil
}

// Save encrypts the state and writes it atomically to disk.
func (s *EncryptedJSONStore) Save(st *State) error {
    plaintext, err := json.Marshal(st)
    if err != nil {
        return fmt.Errorf("store: marshal state: %w", err)
    }

    nonce, ciphertext, err := crypto.Encrypt(s.key, plaintext)
    if err != nil {
        return err
    }

    env := encryptedEnvelope{
        V:          1,
        Nonce:      base64.StdEncoding.EncodeToString(nonce),
        Ciphertext: base64.StdEncoding.EncodeToString(ciphertext),
    }
    envBytes, err := json.Marshal(env)
    if err != nil {
        return fmt.Errorf("store: marshal envelope: %w", err)
    }

    return atomicWrite(s.Path, envBytes)
}

// atomicWrite writes data to a temp file in the same directory as dst,
// then renames it into place (atomic on POSIX).
func atomicWrite(dst string, data []byte) error {
    dir := filepath.Dir(dst)
    tmp, err := os.CreateTemp(dir, ".state_tmp_")
    if err != nil {
        return fmt.Errorf("store: create temp file: %w", err)
    }
    tmpName := tmp.Name()

    if _, err := tmp.Write(data); err != nil {
        tmp.Close()
        os.Remove(tmpName)
        return fmt.Errorf("store: write temp file: %w", err)
    }
    if err := tmp.Close(); err != nil {
        os.Remove(tmpName)
        return fmt.Errorf("store: close temp file: %w", err)
    }
    if err := os.Rename(tmpName, dst); err != nil {
        os.Remove(tmpName)
        return fmt.Errorf("store: rename %s → %s: %w", tmpName, dst, err)
    }
    return nil
}
