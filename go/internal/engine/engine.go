package engine

import (
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
    "time"

    "github.com/user/claude-cheevos/internal/defs"
    "github.com/user/claude-cheevos/internal/store"
)

// UpdateParams holds all the data that a hook passes to the engine.
type UpdateParams struct {
    // CounterUpdates maps counter names to increment amounts (usually 1).
    CounterUpdates map[string]int64
    // CounterSets maps counter names to absolute values to write (used for streaks).
    CounterSets map[string]int64
    // UpdateCheckEpoch, when non-zero, is written to state.LastUpdateCheckEpoch
    // for rate-limiting the daily auto-update check.
    UpdateCheckEpoch int64
    // BinaryUpdateCheckEpoch, when non-zero, is written to state.LastBinaryUpdateCheckEpoch
    // for rate-limiting the daily binary auto-update check.
    BinaryUpdateCheckEpoch int64
    // InstalledVersion, when non-empty, is written to state.InstalledVersion
    // to track the currently installed binary version.
    InstalledVersion string
}

// Notification is the structure appended to notifications.json when an achievement unlocks.
type Notification struct {
    ID          string `json:"id"`
    Name        string `json:"name"`
    Points      int    `json:"points"`
    Description string `json:"description"`
}

// Update applies counter increments/sets, checks achievements, appends notifications,
// and saves state. It must be called while holding the state file lock.
func Update(st *State, d *defs.Definitions, params UpdateParams) ([]Notification, error) {
    now := time.Now().UTC().Format(time.RFC3339)

    // Apply counter increments.
    for k, v := range params.CounterUpdates {
        st.Counters[k] = st.Counters[k] + v
    }
    // Apply counter sets (absolute values, e.g. streak_days).
    for k, v := range params.CounterSets {
        st.Counters[k] = v
    }
    // Record update-check timestamp.
    if params.UpdateCheckEpoch > 0 {
        st.LastUpdateCheckEpoch = params.UpdateCheckEpoch
    }
    // Record binary update-check timestamp.
    if params.BinaryUpdateCheckEpoch > 0 {
        st.LastBinaryUpdateCheckEpoch = params.BinaryUpdateCheckEpoch
    }
    // Record installed version.
    if params.InstalledVersion != "" {
        st.InstalledVersion = params.InstalledVersion
    }

    st.LastUpdated = now

    // Check achievement conditions.
    var newly []Notification
    for i := range d.Achievements {
        ach := &d.Achievements[i]
        if st.IsUnlocked(ach.ID) {
            continue
        }
        if checkCondition(ach.Condition, st, d, ach.ID) {
            st.Unlocked = append(st.Unlocked, ach.ID)
            if st.UnlockTimes == nil {
                st.UnlockTimes = make(map[string]string)
            }
            st.UnlockTimes[ach.ID] = now
            st.Score += ach.Points
            newly = append(newly, Notification{
                ID:          ach.ID,
                Name:        ach.Name,
                Points:      ach.Points,
                Description: ach.Description,
            })
        }
    }

    return newly, nil
}

// AppendNotifications appends newly unlocked notifications to the queue file atomically.
func AppendNotifications(notifFile string, newly []Notification) error {
    if len(newly) == 0 {
        return nil
    }

    var existing []Notification
    if data, err := os.ReadFile(notifFile); err == nil {
        _ = json.Unmarshal(data, &existing) // tolerate missing/empty file
    }

    combined := append(existing, newly...)
    data, err := json.Marshal(combined)
    if err != nil {
        return fmt.Errorf("engine: marshal notifications: %w", err)
    }

    return atomicWrite(notifFile, data)
}

func atomicWrite(dst string, data []byte) error {
    dir := filepath.Dir(dst)
    tmp, err := os.CreateTemp(dir, ".notif_tmp_")
    if err != nil {
        return fmt.Errorf("engine: create temp: %w", err)
    }
    tmpName := tmp.Name()
    if _, err := tmp.Write(data); err != nil {
        tmp.Close()
        os.Remove(tmpName)
        return err
    }
    tmp.Close()
    if err := os.Rename(tmpName, dst); err != nil {
        os.Remove(tmpName)
        return err
    }
    return nil
}

// checkCondition returns true if the achievement's condition is met by the current state.
func checkCondition(cond defs.Condition, st *store.State, d *defs.Definitions, achID string) bool {
    typ := cond.Type
    if typ == "" {
        typ = "counter"
    }

    switch typ {
    case "counter":
        return st.Counters[cond.Counter] >= cond.Threshold

    case "all_of_level":
        // Optional prerequisite.
        if cond.Requires != "" && !st.IsUnlocked(cond.Requires) {
            return false
        }
        // All non-rank achievements of the given level must be unlocked.
        for _, a := range d.Achievements {
            if a.SkillLevel == cond.Level && a.Category != "rank" {
                if !st.IsUnlocked(a.ID) {
                    return false
                }
            }
        }
        return true

    case "all_unlocked":
        if cond.Requires != "" && !st.IsUnlocked(cond.Requires) {
            return false
        }
        for _, a := range d.Achievements {
            if a.ID != achID && !st.IsUnlocked(a.ID) {
                return false
            }
        }
        return true

    case "all_tutorial":
        for _, a := range d.Achievements {
            if a.Tutorial && !st.IsUnlocked(a.ID) {
                return false
            }
        }
        return true

    case "unlocked_count_gte":
        return int64(len(st.Unlocked)) >= cond.Threshold

    default:
        return false
    }
}

// State is an alias to avoid import cycles in tests.
// All engine functions take *store.State directly.
type State = store.State
