package subcmd

import (
    "bufio"
    "bytes"
    "encoding/json"
    "fmt"
    "net/http"
    "os"
    "path/filepath"
    "strings"
    "time"

    "github.com/user/claude-cheevos/internal/store"
)

type leaderboardConf struct {
    Enabled  bool
    UserID   string
    Username string
    Token    string
    APIURL   string
}

// LeaderboardSync reads leaderboard.conf, reads the current score from encrypted
// state, and PUTs it to the leaderboard API. Results are logged to
// ~/.claude/achievements/logs/leaderboard.log. The token is never written to the log.
// Exits silently if leaderboard is disabled or not configured.
func LeaderboardSync(achievementsDir string, key [32]byte) error {
    conf, err := readLeaderboardConf(filepath.Join(achievementsDir, "leaderboard.conf"))
    if err != nil || !conf.Enabled {
        return nil
    }
    if conf.Token == "" || conf.APIURL == "" || conf.UserID == "" {
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

    url := strings.TrimRight(conf.APIURL, "/") + "/users/" + conf.UserID
    req, err := http.NewRequest(http.MethodPut, url, bytes.NewReader(body))
    if err != nil {
        return nil
    }
    req.Header.Set("Authorization", "Bearer "+conf.Token)
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

    // Append to log (token intentionally omitted).
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
        case "TOKEN":
            conf.Token = v
        case "API_URL":
            conf.APIURL = v
        }
    }
    return conf, scanner.Err()
}
