package crypto

import (
	"encoding/base64"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// nonce is a fixed compile-time value used to XOR-obfuscate the HMAC secret
// stored in the binary. It is NOT secret — it only prevents the raw key from
// appearing as a plain string in the binary when inspected with `strings`.
//
// This value must match the nonce used by tools/keygen/main.go.
const obfuscationNonce = "R3VpbGRlbnN0ZXJuU3RyYXNzZW5iYWhuR3VpbGQ="

// LoadKeyFromFile reads the 32-byte AES encryption key from the .key file
// in the given achievements directory. The key file contains a base64-encoded
// 32-byte random value generated at install time.
func LoadKeyFromFile(dir string) ([32]byte, error) {
	path := filepath.Join(dir, ".key")
	data, err := os.ReadFile(path)
	if err != nil {
		return [32]byte{}, fmt.Errorf("crypto: encryption key not found at %s (run cheevos init): %w", path, err)
	}
	raw := strings.TrimSpace(string(data))
	decoded, err := base64.StdEncoding.DecodeString(raw)
	if err != nil {
		return [32]byte{}, fmt.Errorf("crypto: invalid base64 in .key file: %w", err)
	}
	if len(decoded) != 32 {
		return [32]byte{}, fmt.Errorf("crypto: .key must be 32 bytes, got %d", len(decoded))
	}
	var key [32]byte
	copy(key[:], decoded)
	return key, nil
}

// DeobfuscateHMACKey recovers the raw HMAC secret from the XOR-obfuscated value
// that was injected at compile time via -ldflags. Returns the raw 32-byte secret.
func DeobfuscateHMACKey(injected string) ([]byte, error) {
	if injected == "" {
		return nil, errors.New("crypto: HMAC key not injected at build time")
	}
	injectedBytes, err := base64.StdEncoding.DecodeString(injected)
	if err != nil {
		return nil, fmt.Errorf("crypto: invalid base64 for injected HMAC key: %w", err)
	}
	nonceBytes, err := base64.StdEncoding.DecodeString(obfuscationNonce)
	if err != nil {
		return nil, fmt.Errorf("crypto: invalid obfuscation nonce constant: %w", err)
	}
	if len(injectedBytes) < 32 || len(nonceBytes) < 32 {
		return nil, fmt.Errorf("crypto: key or nonce too short (%d, %d)", len(injectedBytes), len(nonceBytes))
	}
	key := make([]byte, 32)
	for i := range 32 {
		key[i] = injectedBytes[i] ^ nonceBytes[i]
	}
	return key, nil
}
