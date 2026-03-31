// leaderboard-keygen produces an encrypted credential blob for leaderboard distribution.
//
// The blob encrypts the API token and URL using the same AES-256 key that the cheevos
// binary uses for state.json, derived from the compile-time HMAC secret via HKDF.
// Only a cheevos binary built with the matching CHEEVOS_HMAC_KEY can decrypt it.
//
// Usage:
//
//	CHEEVOS_HMAC_KEY=<obfuscated-key> go run ./tools/leaderboard-keygen \
//	    --token <api-token> --api-url <api-url>
//
// The CHEEVOS_HMAC_KEY must be the same obfuscated value used to build the binary
// (i.e. the output of `go run ./tools/keygen`, or the value in CHEEVOS_HMAC_KEY at
// build time). Distribute the printed blob to users via:
//
//	bash install.sh --leaderboard-secret <blob>
package main

import (
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/user/claude-cheevos/internal/crypto"
)

func main() {
	token := flag.String("token", "", "API bearer token (required)")
	apiURL := flag.String("api-url", "", "Leaderboard API base URL (required)")
	flag.Parse()

	if *token == "" || *apiURL == "" {
		fmt.Fprintln(os.Stderr, "usage: leaderboard-keygen --token <token> --api-url <url>")
		fmt.Fprintln(os.Stderr, "       CHEEVOS_HMAC_KEY must be set to the key used to build the binary")
		os.Exit(1)
	}

	hmacKeyRaw := os.Getenv("CHEEVOS_HMAC_KEY")
	if hmacKeyRaw == "" {
		fmt.Fprintln(os.Stderr, "leaderboard-keygen: CHEEVOS_HMAC_KEY is not set")
		fmt.Fprintln(os.Stderr, "  Set it to the same value used when building the cheevos binary.")
		os.Exit(1)
	}

	hmacSecret, err := crypto.DeobfuscateHMACKey(hmacKeyRaw)
	if err != nil {
		fmt.Fprintln(os.Stderr, "leaderboard-keygen: failed to deobfuscate HMAC key:", err)
		os.Exit(1)
	}

	stateKey, err := crypto.DeriveStateKey(hmacSecret)
	if err != nil {
		fmt.Fprintln(os.Stderr, "leaderboard-keygen: failed to derive encryption key:", err)
		os.Exit(1)
	}

	type creds struct {
		Token  string `json:"token"`
		APIURL string `json:"api_url"`
	}
	payload, err := json.Marshal(creds{Token: *token, APIURL: *apiURL})
	if err != nil {
		fmt.Fprintln(os.Stderr, "leaderboard-keygen: failed to marshal credentials:", err)
		os.Exit(1)
	}

	nonce, ciphertext, err := crypto.Encrypt(stateKey, payload)
	if err != nil {
		fmt.Fprintln(os.Stderr, "leaderboard-keygen: encryption failed:", err)
		os.Exit(1)
	}

	// Blob format: base64(nonce || ciphertext).
	// The nonce is always 12 bytes (AES-256-GCM standard), so the split point is fixed.
	blob := base64.StdEncoding.EncodeToString(append(nonce, ciphertext...))
	fmt.Println(blob)
}
