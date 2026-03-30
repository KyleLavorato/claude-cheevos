package subcmd

import (
    "bufio"
    "fmt"
    "os"
    "path/filepath"
    "strings"

    "github.com/user/claude-cheevos/internal/crypto"
    "github.com/user/claude-cheevos/internal/defs"
    "github.com/user/claude-cheevos/internal/store"
    "golang.org/x/term"
)

var categories = []struct{ id, label string }{
    {"sessions", "Sessions"},
    {"files", "Files"},
    {"shell", "Shell"},
    {"search", "Search"},
    {"mcp", "MCP Integrations"},
    {"plan_mode", "Plan Mode"},
    {"tokens", "Token Consumption"},
    {"commands", "Commands & Skills"},
    {"context", "Context & Compaction"},
    {"specs", "API Specs"},
    {"reviews", "Code Reviews"},
    {"tests", "Testing"},
    {"misc", "Miscellaneous"},
    {"rank", "Rank Achievements"},
    {"team", "Team Achievements"},
}

// Show lists achievements filtered by unlock status and skill level.
func Show(achievementsDir string, args []string) error {
    filter := "all"         // all | unlocked | locked
    filterSet := false
    levelFilter := "all"    // all | beginner | intermediate | experienced | master | secret
    levelSet := false

    for _, arg := range args {
        switch arg {
        case "-a", "--all":
            filter = "all"; filterSet = true
        case "-u", "--unlocked":
            filter = "unlocked"; filterSet = true
        case "-l", "--locked":
            filter = "locked"; filterSet = true
        case "-B", "--beginner":
            levelFilter = "beginner"; levelSet = true
        case "-I", "--intermediate":
            levelFilter = "intermediate"; levelSet = true
        case "-E", "--experienced":
            levelFilter = "experienced"; levelSet = true
        case "-M", "--master":
            levelFilter = "master"; levelSet = true
        case "-S", "--secret":
            levelFilter = "secret"; levelSet = true
        }
    }

    isTerminal := term.IsTerminal(int(os.Stdin.Fd())) && term.IsTerminal(int(os.Stdout.Fd()))

    if !filterSet && isTerminal {
        filter = promptChoice("Show which achievements?",
            []string{"All", "Unlocked only", "Locked only"},
            []string{"all", "unlocked", "locked"})
    }
    if !levelSet && isTerminal {
        levelFilter = promptChoice("Filter by skill level?",
            []string{"All levels", "Beginner", "Intermediate", "Experienced", "Master", "Secret"},
            []string{"all", "beginner", "intermediate", "experienced", "master", "secret"})
    }

    // ANSI colours (suppressed when stdout is not a terminal).
    bold, dim, green, yellow, cyan, reset := "", "", "", "", "", ""
    if term.IsTerminal(int(os.Stdout.Fd())) {
        bold = "\033[1m"; dim = "\033[2m"; green = "\033[32m"
        yellow = "\033[33m"; cyan = "\033[36m"; reset = "\033[0m"
    }

    key, err := crypto.LoadKeyFromFile(achievementsDir)
    if err != nil {
        return err
    }
    stateFile := filepath.Join(achievementsDir, "state.json")
    st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
    if err != nil {
        return fmt.Errorf("show: load state: %w", err)
    }
    d, err := defs.Load()
    if err != nil {
        return err
    }

    totalCount := len(d.Achievements)
    unlockedCount := len(st.Unlocked)

    // Build filter label.
    var parts []string
    if filter != "all" {
        parts = append(parts, filter+" only")
    }
    if levelFilter != "all" {
        parts = append(parts, levelFilter+" only")
    }
    label := ""
    if len(parts) > 0 {
        label = "  " + dim + "(" + strings.Join(parts, " · ") + ")" + reset
    }

    fmt.Printf("\n%s🏆  Claude Cheevos%s%s\n", bold, reset, label)
    fmt.Printf("Score: %s%d pts%s  ·  %d/%d unlocked\n\n",
        yellow, st.Score, reset, unlockedCount, totalCount)

    for _, cat := range categories {
        var lines []string
        for _, ach := range d.Achievements {
            if ach.Category != cat.id {
                continue
            }
            isUnlocked := st.IsUnlocked(ach.ID)

            if filter == "unlocked" && !isUnlocked {
                continue
            }
            if filter == "locked" && isUnlocked {
                continue
            }
            if levelFilter != "all" && ach.SkillLevel != levelFilter {
                continue
            }

            ptsStr := fmt.Sprintf("+%d pts", ach.Points)
            if isUnlocked {
                unlockDate := ""
                if t, ok := st.UnlockTimes[ach.ID]; ok && len(t) >= 10 {
                    unlockDate = t[:10]
                }
                if unlockDate != "" {
                    lines = append(lines, fmt.Sprintf("  %s✅%s  %-26s %s%-10s%s  %s  %s· %s%s",
                        green, reset, ach.Name, yellow, ptsStr, reset, ach.Description, dim, unlockDate, reset))
                } else {
                    lines = append(lines, fmt.Sprintf("  %s✅%s  %-26s %s%-10s%s  %s",
                        green, reset, ach.Name, yellow, ptsStr, reset, ach.Description))
                }
            } else if ach.Secret {
                lines = append(lines, fmt.Sprintf("  🔮  %-26s %s%-10s%s  %s???%s",
                    ach.Name, yellow, ptsStr, reset, dim, reset))
            } else if ach.Condition.Threshold == 0 && ach.Condition.Counter == "" {
                // Rank-style (no counter threshold to show).
                lines = append(lines, fmt.Sprintf("  🔒  %-26s %-10s  %s%s%s",
                    ach.Name, ptsStr, dim, ach.Description, reset))
            } else {
                current := st.Counters[ach.Condition.Counter]
                lines = append(lines, fmt.Sprintf("  🔒  %-26s %-10s  %s%s  [%d/%d]%s",
                    ach.Name, ptsStr, dim, ach.Description, current, ach.Condition.Threshold, reset))
            }
        }

        if len(lines) == 0 {
            continue
        }
        fmt.Printf("%s%s%s%s\n", bold, cyan, cat.label, reset)
        for _, line := range lines {
            fmt.Println(line)
        }
        fmt.Println()
    }
    return nil
}

func promptChoice(prompt string, labels, values []string) string {
    fmt.Printf("\n\033[1m%s\033[0m\n", prompt)
    for i, label := range labels {
        fmt.Printf("  %d) %s\n", i+1, label)
    }
    fmt.Print("Choice: ")

    scanner := bufio.NewScanner(os.Stdin)
    if scanner.Scan() {
        line := strings.TrimSpace(scanner.Text())
        for i := range labels {
            if line == fmt.Sprintf("%d", i+1) {
                return values[i]
            }
        }
    }
    return values[0] // default to first option
}
