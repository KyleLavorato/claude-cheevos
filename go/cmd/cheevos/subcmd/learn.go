package subcmd

import (
    "fmt"
    "os"
    "path/filepath"
    "strings"

    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/defs"
    "github.com/user/claude-cheevos/internal/store"
    "golang.org/x/term"
)

// tips are the instructional hints for each tutorial achievement (keyed by ID).
var tips = map[string]string{
    "first_session":        "Just open your terminal and run 'claude' to start your first session.",
    "session_10":           "Keep using Claude Code daily — sessions accumulate quickly!",
    "web_search_first":     "Ask Claude a question that needs current info: 'What's the latest version of Node.js?'",
    "back_again":           "Resume a past session: run 'claude --resume' or type /resume inside Claude Code.",
    "files_written_10":     "Ask Claude to create files: 'Create a utils.py with a helper function'",
    "laying_down_the_law":  "Ask Claude: 'Create a CLAUDE.md in this project with instructions for working on this codebase'",
    "spec_first":           "Ask Claude to design an API spec first: 'Create an OpenAPI spec for a user auth service'",
    "files_read_100":       "Ask Claude to read and analyze code: 'Explain what this file does' on any source file.",
    "bash_calls_50":        "Ask Claude to run shell commands: 'Run the tests and show me the output'",
    "git_er_done":          "Ask Claude to commit your work: 'Stage and commit these changes with a good message'",
    "glob_grep_50":         "Ask Claude to search your codebase: 'Find all files that import React'",
    "web_search_25":        "Ask research questions regularly: 'What are the best practices for X?'",
    "tokens_100k":          "Just keep using Claude — tokens accumulate naturally with regular use.",
    "spring_cleaning":      "Type /compact inside Claude Code to manually compact the conversation context.",
    "github_first":         "Ask Claude about a GitHub repo: 'Show me the open PRs in this repo'",
    "pull_request_pioneer": "Ask Claude to open a PR for you: 'Create a pull request for this branch'",
    "jira_first":           "Ask Claude to look up a Jira ticket: 'What's the status of PROJ-123?'",
    "delegation_station":   "Give Claude a broad research task — Claude will launch a sub-agent automatically.",
    "plan_mode_first":      "Ask Claude to plan before implementing: 'Plan how you would add auth to this app'",
    "plan_mode_10":         "Use plan mode for any significant feature — it leads to better outcomes.",
}

// Learn displays the tutorial learning path.
func Learn(achievementsDir string) error {
    isTerminal := term.IsTerminal(int(os.Stdout.Fd()))
    bold, dim, green, yellow, cyan, reset := "", "", "", "", "", ""
    if isTerminal {
        bold = "\033[1m"; dim = "\033[2m"; green = "\033[32m"
        yellow = "\033[33m"; cyan = "\033[36m"; reset = "\033[0m"
    }
    _ = cyan // used in tips display implicitly

    key, err := crypto.LoadKeyFromFile(achievementsDir)
    if err != nil {
        return err
    }
    stateFile := filepath.Join(achievementsDir, "state.json")
    st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
    if err != nil {
        return fmt.Errorf("learn: load state: %w", err)
    }
    d, err := defs.Load()
    if err != nil {
        return err
    }

    // Collect tutorial achievements in definition order.
    var pathIDs []string
    totalPts := 0
    for _, ach := range d.Achievements {
        if ach.Tutorial {
            pathIDs = append(pathIDs, ach.ID)
            totalPts += ach.Points
        }
    }

    earnedPts := 0
    completed := 0
    var lockedIDs []string
    for _, id := range pathIDs {
        if st.IsUnlocked(id) {
            completed++
            if ach := d.ByID(id); ach != nil {
                earnedPts += ach.Points
            }
        } else {
            lockedIDs = append(lockedIDs, id)
        }
    }

    // Progress bar (20 blocks).
    bar := strings.Repeat("░", 20)
    if totalPts > 0 {
        filled := earnedPts * 20 / totalPts
        if filled > 20 {
            filled = 20
        }
        bar = strings.Repeat("█", filled) + strings.Repeat("░", 20-filled)
    }

    fmt.Printf("\n%s🗺️   Claude Cheevos — Tutorial%s\n", bold, reset)
    fmt.Printf("%d/%d complete  ·  %s[%s]%s  %d/%d pts\n",
        completed, len(pathIDs), yellow, bar, reset, earnedPts, totalPts)

    // Up Next (first 3 locked achievements).
    fmt.Printf("\n%s⭐  Up Next%s\n", bold, reset)
    fmt.Println(strings.Repeat("─", 60))

    upNextSet := map[string]bool{}
    upNextList := []string{}
    for _, id := range lockedIDs {
        if len(upNextList) >= 3 {
            break
        }
        upNextSet[id] = true
        upNextList = append(upNextList, id)
    }

    if len(upNextList) == 0 {
        fmt.Println("  🎉 All tutorial achievements complete!")
    } else {
        for _, id := range upNextList {
            ach := d.ByID(id)
            if ach == nil {
                continue
            }
            current := st.Counters[ach.Condition.Counter]
            ptsStr := fmt.Sprintf("+%d pts", ach.Points)
            fmt.Printf("  %s⭐%s  %-26s %s%-10s%s  %s[%d/%d %s]%s\n",
                yellow, reset, ach.Name, yellow, ptsStr, reset,
                dim, current, ach.Condition.Threshold, ach.Condition.Counter, reset)
            fmt.Printf("      %s\n", ach.Description)
            if tip, ok := tips[id]; ok {
                fmt.Printf("      %s💡 %s%s\n", cyan, tip, reset)
            }
            fmt.Println()
        }
    }

    // Full Path.
    fmt.Printf("%sFull Path%s\n", bold, reset)
    fmt.Println(strings.Repeat("─", 60))

    for i, id := range pathIDs {
        ach := d.ByID(id)
        if ach == nil {
            continue
        }
        idx := i + 1
        ptsStr := fmt.Sprintf("+%d pts", ach.Points)
        if st.IsUnlocked(id) {
            fmt.Printf("  %s✅%s  %2d. %-24s %s%-10s%s  %s\n",
                green, reset, idx, ach.Name, yellow, ptsStr, reset, ach.Description)
        } else if upNextSet[id] {
            current := st.Counters[ach.Condition.Counter]
            fmt.Printf("  %s⭐%s  %2d. %-24s %s%-10s%s  %s[%d/%d]%s\n",
                yellow, reset, idx, ach.Name, yellow, ptsStr, reset,
                dim, current, ach.Condition.Threshold, reset)
        } else {
            fmt.Printf("  %s🔒  %2d. %-24s %-10s  [0/%d]%s\n",
                dim, idx, ach.Name, ptsStr, ach.Condition.Threshold, reset)
        }
    }
    fmt.Println()
    return nil
}
