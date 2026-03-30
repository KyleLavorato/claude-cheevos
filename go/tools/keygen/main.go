// keygen generates an XOR-obfuscated HMAC secret for use with -ldflags.
//
// Usage:
//   go run ./tools/keygen
//
// Output (stdout):
//   <base64-obfuscated-key>
//
// This value is passed to:
//   go build -ldflags "-X 'main.hmacSecretRaw=<value>'" ./cmd/cheevos
//
// The nonce used here MUST match the constant in internal/crypto/key.go.
package main

import (
    "crypto/rand"
    "encoding/base64"
    "fmt"
    "os"
)

// obfuscationNonce must match the value in internal/crypto/key.go.
const obfuscationNonce = "R3VpbGRlbnN0ZXJuU3RyYXNzZW5iYWhuR3VpbGQ="

func main() {
    // Generate a random 32-byte HMAC secret.
    raw := make([]byte, 32)
    if _, err := rand.Read(raw); err != nil {
        fmt.Fprintln(os.Stderr, "keygen: failed to generate random key:", err)
        os.Exit(1)
    }

    // XOR with the obfuscation nonce.
    nonce, err := base64.StdEncoding.DecodeString(obfuscationNonce)
    if err != nil {
        fmt.Fprintln(os.Stderr, "keygen: invalid nonce constant:", err)
        os.Exit(1)
    }

    obfuscated := make([]byte, 32)
    for i := range 32 {
        obfuscated[i] = raw[i] ^ nonce[i]
    }

    fmt.Println(base64.StdEncoding.EncodeToString(obfuscated))
}
