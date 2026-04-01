package engine

import (
    "testing"

    "github.com/user/claude-cheevos/internal/defs"
    "github.com/user/claude-cheevos/internal/store"
)

// syntheticDefs returns a small definitions set for testing all condition types.
func syntheticDefs() *defs.Definitions {
    return &defs.Definitions{
        SchemaVersion: 1,
        Achievements: []defs.Achievement{
            {
                ID: "counter_basic", Name: "Counter Basic", Points: 10,
                Category: "misc", SkillLevel: "beginner",
                Condition: defs.Condition{Counter: "bash_calls", Threshold: 5},
            },
            {
                ID: "all_beginner", Name: "All Beginner", Points: 20,
                Category: "rank", SkillLevel: "beginner",
                Condition: defs.Condition{Type: "all_of_level", Level: "beginner"},
            },
            {
                ID: "unlocked_50", Name: "50 Unlocked", Points: 30,
                Category: "rank", SkillLevel: "impossible",
                Condition: defs.Condition{Type: "unlocked_count_gte", Threshold: 2},
            },
            {
                ID: "all_tut", Name: "Tutorial Complete", Points: 15,
                Category: "rank", SkillLevel: "beginner",
                Condition: defs.Condition{Type: "all_tutorial"},
                Tutorial:  false, // this is the meta-achievement, not a tutorial item
            },
            {
                ID:       "tut_item", Name: "Tutorial Item", Points: 5,
                Category: "misc", SkillLevel: "beginner",
                Condition: defs.Condition{Counter: "sessions", Threshold: 1},
                Tutorial:  true,
            },
        },
    }
}

func freshState() *store.State {
    st := store.NewState()
    return st
}

func TestCounterCondition(t *testing.T) {
    d := syntheticDefs()
    st := freshState()
    st.Counters["bash_calls"] = 4

    newly, err := Update(st, d, UpdateParams{
        CounterUpdates: map[string]int64{"bash_calls": 1},
    })
    if err != nil {
        t.Fatalf("Update: %v", err)
    }
    if len(newly) != 1 || newly[0].ID != "counter_basic" {
        t.Fatalf("expected counter_basic to unlock, got: %v", newly)
    }
    if st.Score != 10 {
        t.Errorf("score: got %d want 10", st.Score)
    }
    if !st.IsUnlocked("counter_basic") {
        t.Error("counter_basic should be in Unlocked")
    }
}

func TestNoDoubleUnlock(t *testing.T) {
    d := syntheticDefs()
    st := freshState()
    st.Counters["bash_calls"] = 10
    st.Unlocked = []string{"counter_basic"}
    st.Score = 10

    newly, _ := Update(st, d, UpdateParams{
        CounterUpdates: map[string]int64{"bash_calls": 1},
    })
    for _, n := range newly {
        if n.ID == "counter_basic" {
            t.Error("counter_basic should not unlock twice")
        }
    }
}

func TestCounterSets(t *testing.T) {
    d := syntheticDefs()
    st := freshState()

    _, err := Update(st, d, UpdateParams{
        CounterUpdates: map[string]int64{},
        CounterSets:    map[string]int64{"streak_days": 7},
    })
    if err != nil {
        t.Fatalf("Update: %v", err)
    }
    if st.Counters["streak_days"] != 7 {
        t.Errorf("streak_days: got %d want 7", st.Counters["streak_days"])
    }
}

func TestAllOfLevelCondition(t *testing.T) {
    d := syntheticDefs()
    st := freshState()
    // Pre-unlock the only beginner non-rank achievement.
    st.Unlocked = []string{"counter_basic", "tut_item"}
    st.Score = 15

    newly, err := Update(st, d, UpdateParams{CounterUpdates: map[string]int64{}})
    if err != nil {
        t.Fatalf("Update: %v", err)
    }
    found := false
    for _, n := range newly {
        if n.ID == "all_beginner" {
            found = true
        }
    }
    if !found {
        t.Error("expected all_beginner to unlock when all beginner non-rank achievements are unlocked")
    }
}

func TestUnlockedCountGte(t *testing.T) {
    d := syntheticDefs()
    st := freshState()
    st.Unlocked = []string{"counter_basic"}
    st.Score = 10

    // Unlocking one more should trigger unlocked_count_gte (threshold=2).
    st.Unlocked = append(st.Unlocked, "tut_item")
    st.Score += 5

    newly, err := Update(st, d, UpdateParams{CounterUpdates: map[string]int64{}})
    if err != nil {
        t.Fatalf("Update: %v", err)
    }
    found := false
    for _, n := range newly {
        if n.ID == "unlocked_50" {
            found = true
        }
    }
    if !found {
        t.Errorf("expected unlocked_50 to trigger at 2 unlocked; newly=%v", newly)
    }
}

func TestAllTutorialCondition(t *testing.T) {
    d := syntheticDefs()
    st := freshState()
    st.Unlocked = []string{"tut_item"} // the only tutorial item
    st.Score = 5

    newly, err := Update(st, d, UpdateParams{CounterUpdates: map[string]int64{}})
    if err != nil {
        t.Fatalf("Update: %v", err)
    }
    found := false
    for _, n := range newly {
        if n.ID == "all_tut" {
            found = true
        }
    }
    if !found {
        t.Error("expected all_tut to unlock when all tutorial achievements are done")
    }
}
