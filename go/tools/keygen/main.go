// keygen is the single build-time and admin tool for claude-cheevos key material.
//
// It operates in three modes depending on the flags supplied:
//
// Mode 1 — generate HMAC key only (no flags):
//
//	go run ./tools/keygen
//
//	Generates a fresh XOR-obfuscated HMAC secret and prints it to stdout.
//	Pass the output to the build via:
//	  go build -ldflags "-X 'main.hmacSecretRaw=<value>'" ./cmd/cheevos
//	Or let the Makefile handle it:
//	  make dist
//
// Mode 2 — generate HMAC key + encrypt leaderboard credentials (CHEEVOS_HMAC_KEY not set):
//
//	go run ./tools/keygen --token <api-token> --api-url <api-url>
//
//	Generates a fresh HMAC key, derives the AES-256 state key from it, and encrypts
//	the leaderboard token and API URL into a single sealed blob. Prints:
//	  CHEEVOS_HMAC_KEY=<key>        ← use this for: make dist
//	  LEADERBOARD_SECRET=<blob>     ← distribute this to users
//
// Mode 3 — encrypt leaderboard credentials using an existing HMAC key (CHEEVOS_HMAC_KEY set):
//
//	CHEEVOS_HMAC_KEY=<key> go run ./tools/keygen --token <api-token> --api-url <api-url>
//
//	Encrypts the credentials using the existing key so the binary does not need to be
//	rebuilt. Prints:
//	  LEADERBOARD_SECRET=<blob>     ← distribute this to users
//
// The LEADERBOARD_SECRET blob is passed to end-users via:
//
//	bash install.sh --leaderboard-secret <blob>
//
// The obfuscation nonce used here MUST match the constant in internal/crypto/key.go.
package main

import (
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"flag"
	"fmt"
	"os"

	"github.com/user/claude-cheevos/internal/crypto"
)

// obfuscationNonce must match the value in internal/crypto/key.go.
const obfuscationNonce = "R3VpbGRlbnN0ZXJuU3RyYXNzZW5iYWhuR3VpbGQxMTE="

func main() {
	token := flag.String("token", "", "Leaderboard API bearer token (required for modes 2 and 3)")
	apiURL := flag.String("api-url", "", "Leaderboard API base URL (required for modes 2 and 3)")

	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, "keygen — HMAC key and leaderboard secret generator for claude-cheevos")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "MODE 1  Generate HMAC key only:")
		fmt.Fprintln(os.Stderr, "  go run ./tools/keygen")
		fmt.Fprintln(os.Stderr, "  Output: <obfuscated-key>  (pass to -ldflags or use via: make dist)")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "MODE 2  Generate HMAC key + encrypt leaderboard credentials:")
		fmt.Fprintln(os.Stderr, "  go run ./tools/keygen --token <token> --api-url <url>")
		fmt.Fprintln(os.Stderr, "  Output: CHEEVOS_HMAC_KEY=<key>")
		fmt.Fprintln(os.Stderr, "          LEADERBOARD_SECRET=<blob>")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "MODE 3  Encrypt credentials using an existing HMAC key (binary unchanged):")
		fmt.Fprintln(os.Stderr, "  CHEEVOS_HMAC_KEY=<key> go run ./tools/keygen --token <token> --api-url <url>")
		fmt.Fprintln(os.Stderr, "  Output: LEADERBOARD_SECRET=<blob>")
		fmt.Fprintln(os.Stderr, "")
		fmt.Fprintln(os.Stderr, "Distribute the LEADERBOARD_SECRET to users via:")
		fmt.Fprintln(os.Stderr, "  bash install.sh --leaderboard-secret <blob>")
	}

	flag.Parse()

	wantsLeaderboard := *token != "" || *apiURL != ""

	if wantsLeaderboard {
		if *token == "" || *apiURL == "" {
			fmt.Fprintln(os.Stderr, "keygen: --token and --api-url must both be provided together")
			fmt.Fprintln(os.Stderr, "Run with --help for usage.")
			os.Exit(1)
		}
		runEncryptMode(*token, *apiURL)
		return
	}

	// Mode 1: generate HMAC key only.
	runKeygenMode()
}

// runKeygenMode generates a fresh obfuscated HMAC key and prints it to stdout.
// This is the original behaviour, consumed by the Makefile via -ldflags.
func runKeygenMode() {
	key := generateObfuscatedKey()
	fmt.Println(key)
}

// runEncryptMode encrypts the leaderboard token and API URL.
// If CHEEVOS_HMAC_KEY is set it uses that key (mode 3); otherwise it generates
// a fresh one and prints it alongside the secret (mode 2).
func runEncryptMode(token, apiURL string) {
	existingKey := os.Getenv("CHEEVOS_HMAC_KEY")
	freshKey := ""

	var hmacKeyRaw string
	if existingKey != "" {
		hmacKeyRaw = existingKey
	} else {
		freshKey = generateObfuscatedKey()
		hmacKeyRaw = freshKey
	}

	hmacSecret, err := crypto.DeobfuscateHMACKey(hmacKeyRaw)
	if err != nil {
		fmt.Fprintln(os.Stderr, "keygen: failed to deobfuscate HMAC key:", err)
		os.Exit(1)
	}

	stateKey, err := crypto.DeriveStateKey(hmacSecret)
	if err != nil {
		fmt.Fprintln(os.Stderr, "keygen: failed to derive encryption key:", err)
		os.Exit(1)
	}

	type creds struct {
		Token  string `json:"token"`
		APIURL string `json:"api_url"`
	}
	payload, err := json.Marshal(creds{Token: token, APIURL: apiURL})
	if err != nil {
		fmt.Fprintln(os.Stderr, "keygen: failed to marshal credentials:", err)
		os.Exit(1)
	}

	nonce, ciphertext, err := crypto.Encrypt(stateKey, payload)
	if err != nil {
		fmt.Fprintln(os.Stderr, "keygen: encryption failed:", err)
		os.Exit(1)
	}

	// Blob format: base64(nonce || ciphertext). Nonce is always 12 bytes (AES-256-GCM).
	blob := base64.StdEncoding.EncodeToString(append(nonce, ciphertext...))

	if freshKey != "" {
		fmt.Printf("CHEEVOS_HMAC_KEY=%s\n", freshKey)
	}
	fmt.Printf("LEADERBOARD_SECRET=%s\n", blob)
}

// generateObfuscatedKey generates a fresh 32-byte random secret and XOR-obfuscates
// it with the obfuscation nonce, returning a base64-encoded string suitable for -ldflags.
func generateObfuscatedKey() string {
	raw := make([]byte, 32)
	if _, err := rand.Read(raw); err != nil {
		fmt.Fprintln(os.Stderr, "keygen: failed to generate random key:", err)
		os.Exit(1)
	}

	nonce, err := base64.StdEncoding.DecodeString(obfuscationNonce)
	if err != nil {
		fmt.Fprintln(os.Stderr, "keygen: invalid nonce constant:", err)
		os.Exit(1)
	}

	obfuscated := make([]byte, 32)
	for i := range 32 {
		obfuscated[i] = raw[i] ^ nonce[i]
	}
	return base64.StdEncoding.EncodeToString(obfuscated)
}
