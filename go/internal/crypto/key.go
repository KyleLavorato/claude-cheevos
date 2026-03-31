package crypto

import (
	"crypto/sha256"
	"encoding/base64"
	"errors"
	"fmt"
	"io"

	"golang.org/x/crypto/hkdf"
)

// obfuscationNonce is a fixed compile-time value used to XOR-obfuscate the HMAC secret
// stored in the binary. It is NOT secret — it only prevents the raw key from
// appearing as a plain string in the binary when inspected with `strings`.
//
// This value must match the nonce used by tools/keygen/main.go.
const obfuscationNonce = "R3VpbGRlbnN0ZXJuU3RyYXNzZW5iYWhuR3VpbGQxMTE="

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

// DeriveStateKey derives the 32-byte AES-256 encryption key for state.json from
// the HMAC secret baked into the binary. Uses HKDF-SHA256 with a fixed info string.
// The same binary always produces the same key — no per-install key file needed.
func DeriveStateKey(hmacSecret []byte) ([32]byte, error) {
	r := hkdf.New(sha256.New, hmacSecret, nil, []byte("cheevos-state-key"))
	var key [32]byte
	if _, err := io.ReadFull(r, key[:]); err != nil {
		return [32]byte{}, fmt.Errorf("crypto: derive state key: %w", err)
	}
	return key, nil
}
