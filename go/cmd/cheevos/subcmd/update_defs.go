package subcmd

import (
    "encoding/json"
    "fmt"
    "io"
    "net/http"
    "os"
    "path/filepath"
    "time"

    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/defs"
    "github.com/user/claude-cheevos/internal/engine"
    "github.com/user/claude-cheevos/internal/lock"
    "github.com/user/claude-cheevos/internal/notify"
    "github.com/user/claude-cheevos/internal/store"
)

const (
    githubDefsURL    = "https://raw.githubusercontent.com/KyleLavorato/claude-cheevos/main/data/definitions.json"
    updateIntervalS  = 86400 // 24 hours
)

// UpdateDefs checks the public GitHub repo for new achievement definitions,
// merges any new ones into the on-disk override file, records the check time in
// state, and fires an OS notification if new achievements were added.
//
// Exits silently (no error) on network failure or if checked within the last 24h,
// matching the behaviour of the original check-updates.sh.
func UpdateDefs(achievementsDir string, force bool) error {
    // Rate-limit check: read last_update_check_epoch from state (no lock needed — read-only).
    key, err := crypto.LoadKeyFromFile(achievementsDir)
    if err != nil {
        return nil // state not initialised yet — skip silently
    }
    stateFile := filepath.Join(achievementsDir, "state.json")
    st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
    if err != nil {
        return nil
    }

    now := time.Now().Unix()
    if !force && now-st.LastUpdateCheckEpoch < updateIntervalS {
        return nil // checked recently — exit silently
    }

    // Fetch remote definitions.json.
    client := &http.Client{Timeout: 10 * time.Second}
    resp, err := client.Get(githubDefsURL)
    if err != nil {
        return nil // network unavailable — exit silently
    }
    defer resp.Body.Close()
    if resp.StatusCode != http.StatusOK {
        return nil
    }
    remoteData, err := io.ReadAll(resp.Body)
    if err != nil {
        return nil
    }

    // Validate remote JSON.
    var remoteDefs defs.Definitions
    if err := json.Unmarshal(remoteData, &remoteDefs); err != nil {
        return nil // invalid JSON — exit silently
    }

    // Load local definitions (override file or embedded).
    localDefs, err := defs.Load(achievementsDir)
    if err != nil {
        return nil
    }

    // Find IDs in remote that are absent locally.
    localIDs := make(map[string]bool, len(localDefs.Achievements))
    for _, a := range localDefs.Achievements {
        localIDs[a.ID] = true
    }
    var newAchs []defs.Achievement
    for _, a := range remoteDefs.Achievements {
        if !localIDs[a.ID] {
            newAchs = append(newAchs, a)
        }
    }

    // Write merged override file and record timestamp regardless of whether new
    // achievements were found (so we don't re-check for another 24h).
    overridePath := filepath.Join(achievementsDir, "definitions.json")
    if len(newAchs) > 0 {
        merged := *localDefs
        merged.Achievements = append(merged.Achievements, newAchs...)
        data, err := json.MarshalIndent(merged, "", "    ")
        if err == nil {
            tmp, terr := os.CreateTemp(achievementsDir, ".defs_tmp_")
            if terr == nil {
                tmpName := tmp.Name()
                tmp.Write(data)
                tmp.Close()
                os.Rename(tmpName, overridePath)
            }
        }
    }

    // Record last_update_check_epoch in state under lock.
    lockFile := filepath.Join(achievementsDir, "state.lock")
    l := lock.New(lockFile)
    if err := l.Lock(5 * time.Second); err != nil {
        return nil // can't lock — skip silently
    }
    defer l.Unlock()

    // Re-load to get the freshest state (another hook may have written since our read).
    st, err = store.NewEncryptedJSONStore(stateFile, key).Load()
    if err != nil {
        return nil
    }
    params := engine.UpdateParams{
        CounterUpdates:   map[string]int64{},
        UpdateCheckEpoch: now,
    }
    updatedDefs, err := defs.Load(achievementsDir)
    if err != nil {
        updatedDefs = localDefs
    }
    engine.Update(st, updatedDefs, params) //nolint:errcheck — no-op counters
    store.NewEncryptedJSONStore(stateFile, key).Save(st) //nolint:errcheck

    // Fire OS notification if new achievements were added.
    if len(newAchs) > 0 {
        names := make([]string, 0, len(newAchs))
        for _, a := range newAchs {
            names = append(names, a.Name)
        }
        var title, body string
        if len(newAchs) == 1 {
            title = "🎁 New Achievement Available!"
            body = names[0]
        } else {
            title = fmt.Sprintf("🎁 %d New Achievements Available!", len(newAchs))
            body = joinNames(names)
        }
        _ = notify.Send(title, body)
        fmt.Fprintf(os.Stderr, "cheevos: %d new achievement(s) added: %s\n", len(newAchs), body)
    }

    return nil
}

func joinNames(names []string) string {
    result := ""
    for i, n := range names {
        if i > 0 {
            result += ", "
        }
        result += n
    }
    return result
}
