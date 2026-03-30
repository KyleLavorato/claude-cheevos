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

// TeamStats displays the user's contribution to team achievements.
func TeamStats(achievementsDir string) error {
	// Read team config
	confPath := filepath.Join(achievementsDir, "leaderboard.conf")
	teamConf, err := readTeamConf(confPath)
	if err != nil {
		// Config file doesn't exist or can't be read - show no team message
		return showNoTeamMessage()
	}
	if teamConf.TeamID == "" {
		return showNoTeamMessage()
	}

	// ANSI colours (suppressed when stdout is not a terminal).
	bold, dim, green, yellow, cyan, blue, reset := "", "", "", "", "", "", ""
	if term.IsTerminal(int(os.Stdout.Fd())) {
		bold = "\033[1m"; dim = "\033[2m"; green = "\033[32m"
		yellow = "\033[33m"; cyan = "\033[36m"; blue = "\033[34m"; reset = "\033[0m"
	}

	// Load state
	key, err := crypto.LoadKeyFromFile(achievementsDir)
	if err != nil {
		return fmt.Errorf("failed to load encryption key: %w", err)
	}
	stateFile := filepath.Join(achievementsDir, "state.json")
	st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	// Load definitions
	d, err := defs.LoadWithOverride(achievementsDir)
	if err != nil {
		return fmt.Errorf("failed to load definitions: %w", err)
	}

	// Display header
	fmt.Printf("\n%s🤝 Team: %s%s%s\n", bold, blue, teamConf.TeamName, reset)
	if teamConf.TeamName == "" {
		fmt.Printf("\n%s🤝 Team: %s%s%s\n", bold, blue, teamConf.TeamID, reset)
	}
	fmt.Printf("────────────────────────────────────────────────────────────\n")
	fmt.Printf("%sYour Contribution%s\n\n", bold, reset)

	// Display personal stats
	fmt.Printf("  %s📊 Score:%s          %d pts\n", cyan, reset, st.Score)
	fmt.Printf("  %s💼 Sessions:%s       %d\n", cyan, reset, st.Counters["sessions"])
	fmt.Printf("  %s📖 Files read:%s     %d\n", cyan, reset, st.Counters["files_read"])
	fmt.Printf("  %s✍️  Files written:%s  %d\n", cyan, reset, st.Counters["files_written"])
	fmt.Printf("  %s👀 Code reviews:%s   %d\n", cyan, reset, st.Counters["code_reviews"])
	fmt.Printf("  %s🎫 Tokens used:%s    %d\n", cyan, reset, st.Counters["tokens_consumed"])

	// Display team achievement progress
	fmt.Printf("\n%sTeam Achievement Progress%s\n", bold, reset)
	fmt.Printf("────────────────────────────────────────────────────────────\n")

	// Filter team achievements
	teamAchs := []defs.Achievement{}
	for _, ach := range d.Achievements {
		if ach.Team {
			teamAchs = append(teamAchs, ach)
		}
	}

	if len(teamAchs) == 0 {
		fmt.Printf("%sNo team achievements defined yet.%s\n", dim, reset)
		fmt.Printf("%sTeam achievements will appear here when they're added to definitions.json%s\n\n", dim, reset)
		return nil
	}

	// Display each team achievement
	for _, ach := range teamAchs {
		isUnlocked := false
		for _, uid := range st.Unlocked {
			if uid == ach.ID {
				isUnlocked = true
				break
			}
		}

		if isUnlocked {
			fmt.Printf("\n  %s✅ %s%s%s %s+%d pts%s\n",
				green, bold, ach.Name, reset, yellow, ach.Points, reset)
			fmt.Printf("      %s\n", ach.Description)
		} else {
			// Show progress if counter exists
			current := int64(0)
			if ach.Condition.Counter != "" {
				current = st.Counters[ach.Condition.Counter]
			}
			fmt.Printf("\n  %s🔒 %s%s%s %s+%d pts%s", dim, bold, ach.Name, reset, yellow, ach.Points, reset)
			if ach.Condition.Threshold > 0 {
				fmt.Printf("  %s[%d/%d]%s\n", dim, current, ach.Condition.Threshold, reset)
			} else {
				fmt.Printf("\n")
			}
			fmt.Printf("      %s\n", ach.Description)
		}
	}

	fmt.Printf("\n%sNote: Team achievements require coordination with your teammates.%s\n", dim, reset)
	fmt.Printf("%sYour individual progress counts toward team totals.%s\n\n", dim, reset)

	return nil
}

type teamConf struct {
	TeamID   string
	TeamName string
}

func readTeamConf(path string) (teamConf, error) {
	f, err := os.Open(path)
	if err != nil {
		return teamConf{}, err
	}
	defer f.Close()

	conf := teamConf{}
	scanner := bufio.NewScanner(f)
	for scanner.Scan() {
		line := scanner.Text()
		k, v, ok := strings.Cut(line, "=")
		if !ok {
			continue
		}
		switch k {
		case "TEAM_ID":
			conf.TeamID = v
		case "TEAM_NAME":
			conf.TeamName = v
		}
	}
	return conf, scanner.Err()
}

func showNoTeamMessage() error {
	bold, dim, cyan, reset := "", "", "", ""
	if term.IsTerminal(int(os.Stdout.Fd())) {
		bold = "\033[1m"; dim = "\033[2m"; cyan = "\033[36m"; reset = "\033[0m"
	}

	fmt.Printf("\n%s🤝 Team Achievements%s\n", bold, reset)
	fmt.Printf("────────────────────────────────────────────────────────────\n")
	fmt.Printf("%sYou are not currently part of a team.%s\n\n", dim, reset)
	fmt.Printf("To join or create a team, run:\n")
	fmt.Printf("  %sbash install.sh --token <token> --api-url <url> --team-id <team-id> --team-name \"Team Name\"%s\n\n", cyan, reset)
	fmt.Printf("Team achievements unlock when %sall team members%s reach their goals,\n", bold, reset)
	fmt.Printf("or when the team's %saggregate stats%s hit certain thresholds.\n\n", bold, reset)

	return nil
}
