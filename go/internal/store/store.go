package store

// State is the in-memory representation of state.json.
type State struct {
    SchemaVersion         int               `json:"schema_version"`
    Score                 int               `json:"score"`
    Counters              map[string]int64  `json:"counters"`
    Unlocked              []string          `json:"unlocked"`
    UnlockTimes           map[string]string `json:"unlock_times"`
    ModelsUsed                 []string          `json:"models_used"`
    LastSessionModelCheck      string            `json:"last_session_model_check"`
    LastUpdateCheckEpoch       int64             `json:"last_update_check_epoch,omitempty"`
    LastBinaryUpdateCheckEpoch int64             `json:"last_binary_update_check_epoch,omitempty"`
    InstalledVersion           string            `json:"installed_version,omitempty"`
    LastUpdated                string            `json:"last_updated"`
}

// StateStore abstracts the state persistence layer.
// The concrete implementation is EncryptedJSONStore.
// Swap in EncryptedSQLiteStore (or any other) by implementing this interface.
type StateStore interface {
    Load() (*State, error)
    Save(*State) error
    Exists() bool
}

// NewState returns a fresh default State.
func NewState() *State {
    return &State{
        SchemaVersion: 1,
        Score:         0,
        Counters:      make(map[string]int64),
        Unlocked:      []string{},
        UnlockTimes:   make(map[string]string),
        ModelsUsed:    []string{},
    }
}

// IsUnlocked reports whether the given achievement ID is already in Unlocked.
func (s *State) IsUnlocked(id string) bool {
    for _, u := range s.Unlocked {
        if u == id {
            return true
        }
    }
    return false
}
