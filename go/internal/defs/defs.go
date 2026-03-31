package defs

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

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

// Load reads and parses definitions.json from the given achievements directory.
// Returns a hard error if the file is missing or unparseable.
func Load(dir string) (*Definitions, error) {
	path := filepath.Join(dir, "definitions.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("defs: definitions.json not found in %s — re-run install.sh to restore it: %w", dir, err)
	}
	var d Definitions
	if err := json.Unmarshal(data, &d); err != nil {
		return nil, fmt.Errorf("defs: failed to parse %s: %w", path, err)
	}
	return &d, nil
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
