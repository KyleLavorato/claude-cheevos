package subcmd

import (
	"bufio"
	"bytes"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/user/claude-cheevos/internal/crypto"
	"github.com/user/claude-cheevos/internal/store"
)

type leaderboardConf struct {
	Enabled  bool
	UserID   string
	Username string
	Secret   string
}

type leaderboardCreds struct {
	Token  string `json:"token"`
	APIURL string `json:"api_url"`
}

// LeaderboardSync reads leaderboard.conf, decrypts the credential secret, reads the
// current score from encrypted state, and PUTs it to the leaderboard API. Results are
// logged to ~/.claude/achievements/logs/leaderboard.log. Credentials are never written
// to the log. Exits silently if leaderboard is disabled or not configured.
func LeaderboardSync(achievementsDir string, key [32]byte) error {
	conf, err := readLeaderboardConf(filepath.Join(achievementsDir, "leaderboard.conf"))
	if err != nil || !conf.Enabled {
		return nil
	}
	if conf.Secret == "" || conf.UserID == "" {
		return nil
	}

	creds, err := decryptLeaderboardCreds(conf.Secret, key)
	if err != nil || creds.Token == "" || creds.APIURL == "" {
		return nil
	}

	stateFile := filepath.Join(achievementsDir, "state.json")
	st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
	if err != nil {
		return nil
	}

	unlockCount := len(st.Unlocked)
	lastUpdated := time.Now().UTC().Format(time.RFC3339)

	type payload struct {
		Username    string `json:"username"`
		Score       int    `json:"score"`
		UnlockCount int    `json:"unlock_count"`
		LastUpdated string `json:"last_updated"`
	}
	body, _ := json.Marshal(payload{
		Username:    conf.Username,
		Score:       st.Score,
		UnlockCount: unlockCount,
		LastUpdated: lastUpdated,
	})

	url := strings.TrimRight(creds.APIURL, "/") + "/users/" + conf.UserID
	req, err := http.NewRequest(http.MethodPut, url, bytes.NewReader(body))
	if err != nil {
		return nil
	}
	req.Header.Set("Authorization", "Bearer "+creds.Token)
	req.Header.Set("Content-Type", "application/json")

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	httpCode := 0
	respBody := ""
	if err == nil {
		httpCode = resp.StatusCode
		buf := new(bytes.Buffer)
		buf.ReadFrom(resp.Body)
		resp.Body.Close()
		respBody = strings.TrimSpace(buf.String())
	}

	// Append to log — credentials intentionally omitted.
	logDir := filepath.Join(achievementsDir, "logs")
	os.MkdirAll(logDir, 0700)
	logFile := filepath.Join(logDir, "leaderboard.log")
	f, lerr := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600)
	if lerr == nil {
		ts := time.Now().UTC().Format(time.RFC3339)
		fmt.Fprintf(f, "[%s] PUT /users/%s score=%d unlocks=%d http=%d body=%s\n",
			ts, conf.UserID, st.Score, unlockCount, httpCode, respBody)
		f.Close()
	}

	return nil
}

// LeaderboardDelete reads leaderboard.conf, decrypts credentials, and sends a DELETE
// request to remove the user's entry from the leaderboard. Exits silently (nil error) if
// leaderboard is disabled or not configured. Returns an error if the HTTP call was made
// but returned a non-200 status, so the caller can report failure to the user.
func LeaderboardDelete(achievementsDir string, key [32]byte) error {
	conf, err := readLeaderboardConf(filepath.Join(achievementsDir, "leaderboard.conf"))
	if err != nil || !conf.Enabled {
		return nil
	}
	if conf.Secret == "" || conf.UserID == "" {
		return nil
	}

	creds, err := decryptLeaderboardCreds(conf.Secret, key)
	if err != nil || creds.Token == "" || creds.APIURL == "" {
		return fmt.Errorf("leaderboard-delete: could not decrypt credentials: %w", err)
	}

	url := strings.TrimRight(creds.APIURL, "/") + "/users/" + conf.UserID
	req, err := http.NewRequest(http.MethodDelete, url, nil)
	if err != nil {
		return fmt.Errorf("leaderboard-delete: failed to build request: %w", err)
	}
	req.Header.Set("Authorization", "Bearer "+creds.Token)

	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Do(req)
	httpCode := 0
	respBody := ""
	if err != nil {
		return fmt.Errorf("leaderboard-delete: request failed: %w", err)
	}
	httpCode = resp.StatusCode
	buf := new(bytes.Buffer)
	buf.ReadFrom(resp.Body)
	resp.Body.Close()
	respBody = strings.TrimSpace(buf.String())

	// Append to log.
	logDir := filepath.Join(achievementsDir, "logs")
	os.MkdirAll(logDir, 0700)
	logFile := filepath.Join(logDir, "leaderboard.log")
	if f, lerr := os.OpenFile(logFile, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0600); lerr == nil {
		ts := time.Now().UTC().Format(time.RFC3339)
		fmt.Fprintf(f, "[%s] DELETE /users/%s http=%d body=%s\n",
			ts, conf.UserID, httpCode, respBody)
		f.Close()
	}

	if httpCode != 200 {
		return fmt.Errorf("leaderboard-delete: server returned HTTP %d", httpCode)
	}
	return nil
}

// decryptLeaderboardCreds decrypts a blob produced by leaderboard-keygen and returns
// the API token and URL. The blob is base64(nonce || ciphertext) where nonce is 12 bytes.
// Credentials exist only in memory and are never written to disk or logs.
func decryptLeaderboardCreds(secret string, key [32]byte) (leaderboardCreds, error) {
	decoded, err := base64.StdEncoding.DecodeString(secret)
	if err != nil {
		return leaderboardCreds{}, fmt.Errorf("leaderboard: invalid secret encoding: %w", err)
	}
	// 12-byte GCM nonce + at least 1 byte of ciphertext + 16-byte GCM tag.
	if len(decoded) < 29 {
		return leaderboardCreds{}, fmt.Errorf("leaderboard: secret too short")
	}

	nonce := decoded[:12]
	ciphertext := decoded[12:]

	plaintext, err := crypto.Decrypt(key, nonce, ciphertext)
	if err != nil {
		return leaderboardCreds{}, fmt.Errorf("leaderboard: failed to decrypt credentials: %w", err)
	}

	var creds leaderboardCreds
	if err := json.Unmarshal(plaintext, &creds); err != nil {
		return leaderboardCreds{}, fmt.Errorf("leaderboard: failed to parse decrypted credentials: %w", err)
	}
	return creds, nil
}

func readLeaderboardConf(path string) (leaderboardConf, error) {
	f, err := os.Open(path)
	if err != nil {
		return leaderboardConf{}, err
	}
	defer f.Close()

	conf := leaderboardConf{}
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		switch k {
		case "LEADERBOARD_ENABLED":
			conf.Enabled = v == "true"
		case "USER_ID":
			conf.UserID = v
		case "USERNAME":
			conf.Username = v
		case "LEADERBOARD_SECRET":
			conf.Secret = v
		}
	}
	return conf, scanner.Err()
}
