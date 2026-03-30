package defs

import (
    _ "embed"
    "encoding/json"
    "fmt"
    "os"
    "path/filepath"
)

//go:embed definitions.json
var definitionsJSON []byte

// Definitions is the top-level structure of definitions.json.
type Definitions struct {
    SchemaVersion int           `json:"schema_version"`
    Achievements  []Achievement `json:"achievements"`
}

// Achievement represents a single achievement entry.
type Achievement struct {
    ID          string    `json:"id"`
    Name        string    `json:"name"`
    Description string    `json:"description"`
    Points      int       `json:"points"`
    Category    string    `json:"category"`
    SkillLevel  string    `json:"skill_level"`
    Condition   Condition `json:"condition"`
    Tutorial    bool      `json:"tutorial"`
    Secret      bool      `json:"secret"`
}

// Condition describes when an achievement is unlocked.
type Condition struct {
    // Type is the condition kind. Empty string or "counter" means a simple counter threshold.
    // Other values: "all_of_level", "all_unlocked", "all_tutorial", "unlocked_count_gte".
    Type      string `json:"type"`
    Counter   string `json:"counter"`
    Threshold int64  `json:"threshold"`
    Level     string `json:"level"`
    Requires  string `json:"requires"`
}

var loaded *Definitions

// LoadWithOverride loads definitions for the given achievements directory.
// If an on-disk override file (definitions.json) exists in dir, it is preferred
// over the embedded copy. This allows update-defs to hot-add new achievements
// without recompiling. Falls back to the embedded copy if the file is absent or unreadable.
func LoadWithOverride(dir string) (*Definitions, error) {
    overridePath := filepath.Join(dir, "definitions.json")
    if data, err := os.ReadFile(overridePath); err == nil {
        var d Definitions
        if jsonErr := json.Unmarshal(data, &d); jsonErr == nil {
            return &d, nil
        }
    }
    return Load()
}

// Load returns the embedded achievement definitions.
// The result is cached after the first call.
func Load() (*Definitions, error) {
    if loaded != nil {
        return loaded, nil
    }
    var d Definitions
    if err := json.Unmarshal(definitionsJSON, &d); err != nil {
        return nil, fmt.Errorf("defs: failed to parse definitions.json: %w", err)
    }
    loaded = &d
    return loaded, nil
}

// ByID returns the achievement with the given ID, or nil.
func (d *Definitions) ByID(id string) *Achievement {
    for i := range d.Achievements {
        if d.Achievements[i].ID == id {
            return &d.Achievements[i]
        }
    }
    return nil
}
