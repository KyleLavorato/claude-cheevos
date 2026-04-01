package subcmd

import (
	"context"
	"embed"
	"encoding/json"
	"fmt"
	"io/fs"
	"net"
	"net/http"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"runtime"
	"strings"
	"syscall"
	"time"

	"github.com/user/claude-cheevos/internal/defs"
	"github.com/user/claude-cheevos/internal/store"
)

//go:embed static
var serveStaticFiles embed.FS

// ─── Response types ───────────────────────────────────────────────────────────

type achievementView struct {
	ID          string `json:"id"`
	Name        string `json:"name"`
	Description string `json:"description"`
	Points      int    `json:"points"`
	Category    string `json:"category"`
	SkillLevel  string `json:"skill_level"`
	Counter     string `json:"counter"`
	Threshold   int64  `json:"threshold"`
	IsUnlocked  bool   `json:"is_unlocked"`
	UnlockDate  string `json:"unlock_date"`
	Current     int64  `json:"current"`
	Tutorial    bool   `json:"tutorial"`
}

type serveAPIResponse struct {
	Score         int               `json:"score"`
	TotalPts      int               `json:"total_pts"`
	UnlockedCount int               `json:"unlocked_count"`
	TotalCount    int               `json:"total_count"`
	Achievements  []achievementView `json:"achievements"`
}

// ─── Data loading ─────────────────────────────────────────────────────────────

func buildAPIResponse(achievementsDir string, key [32]byte) (*serveAPIResponse, error) {
	stateFile := filepath.Join(achievementsDir, "state.json")
	st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
	if err != nil {
		return nil, fmt.Errorf("serve: %w", err)
	}

	d, err := defs.Load(achievementsDir)
	if err != nil {
		return nil, fmt.Errorf("serve: %w", err)
	}

	unlockedSet := make(map[string]bool, len(st.Unlocked))
	for _, id := range st.Unlocked {
		unlockedSet[id] = true
	}

	totalPts := 0
	views := make([]achievementView, 0, len(d.Achievements))
	for _, a := range d.Achievements {
		totalPts += a.Points

		unlockDate := ""
		if ts, ok := st.UnlockTimes[a.ID]; ok && len(ts) >= 10 {
			unlockDate = ts[:10]
		}

		current := int64(0)
		if a.Condition.Counter != "" {
			current = st.Counters[a.Condition.Counter]
		}

		views = append(views, achievementView{
			ID:          a.ID,
			Name:        a.Name,
			Description: a.Description,
			Points:      a.Points,
			Category:    a.Category,
			SkillLevel:  a.SkillLevel,
			Counter:     a.Condition.Counter,
			Threshold:   a.Condition.Threshold,
			IsUnlocked:  unlockedSet[a.ID],
			UnlockDate:  unlockDate,
			Current:     current,
			Tutorial:    a.Tutorial,
		})
	}

	return &serveAPIResponse{
		Score:         st.Score,
		TotalPts:      totalPts,
		UnlockedCount: len(st.Unlocked),
		TotalCount:    len(d.Achievements),
		Achievements:  views,
	}, nil
}

// ─── Browser opener ───────────────────────────────────────────────────────────

// isWSL detects if we're running inside Windows Subsystem for Linux.
func isWSL() bool {
	data, err := os.ReadFile("/proc/version")
	if err != nil {
		return false
	}
	version := strings.ToLower(string(data))
	return strings.Contains(version, "microsoft") || strings.Contains(version, "wsl")
}

func openBrowser(url string) {
	time.Sleep(150 * time.Millisecond)
	var cmd string
	var args []string
	switch runtime.GOOS {
	case "darwin":
		cmd, args = "open", []string{url}
	case "linux":
		if isWSL() {
			// In WSL, launch Edge using Windows cmd.exe
			cmd, args = "cmd.exe", []string{"/c", "start", "microsoft-edge:" + url}
		} else {
			cmd, args = "xdg-open", []string{url}
		}
	case "windows":
		cmd, args = "cmd", []string{"/c", "start", url}
	default:
		fmt.Fprintf(os.Stderr, "Open your browser at: %s\n", url)
		return
	}
	if err := exec.Command(cmd, args...).Start(); err != nil {
		fmt.Fprintf(os.Stderr, "Could not open browser automatically.\nOpen: %s\n", url)
	}
}

// ─── Serve ────────────────────────────────────────────────────────────────────

// Serve starts the achievement browser web UI on a random local port and opens
// the browser. It blocks until the user clicks Done, presses Ctrl-C, or sends
// SIGTERM. State is re-read from disk on every /api/data request.
func Serve(achievementsDir string, key [32]byte) error {
	// Find a free port.
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return fmt.Errorf("serve: cannot bind: %w", err)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close()

	url := fmt.Sprintf("http://127.0.0.1:%d", port)

	shutdown := make(chan struct{})

	mux := http.NewServeMux()

	// Serve embedded static files.
	sub, err := fs.Sub(serveStaticFiles, "static")
	if err != nil {
		return fmt.Errorf("serve: embed error: %w", err)
	}
	mux.Handle("/", http.FileServer(http.FS(sub)))

	// /api/data — re-reads from disk on every call so live state is reflected.
	mux.HandleFunc("/api/data", func(w http.ResponseWriter, r *http.Request) {
		resp, err := buildAPIResponse(achievementsDir, key)
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("Cache-Control", "no-store")
		if encErr := json.NewEncoder(w).Encode(resp); encErr != nil {
			fmt.Fprintf(os.Stderr, "serve: encode error: %v\n", encErr)
		}
	})

	// /api/close — triggered by the Done button in the browser.
	mux.HandleFunc("/api/close", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		fmt.Fprint(w, `{"status":"closing"}`)
		go func() {
			time.Sleep(100 * time.Millisecond)
			close(shutdown)
		}()
	})

	srv := &http.Server{
		Addr:    fmt.Sprintf("127.0.0.1:%d", port),
		Handler: mux,
	}

	go func() {
		if srvErr := srv.ListenAndServe(); srvErr != nil && srvErr != http.ErrServerClosed {
			fmt.Fprintf(os.Stderr, "serve: %v\n", srvErr)
		}
	}()

	fmt.Printf("🏆 Achievement browser → %s\n", url)
	fmt.Println("   Press Ctrl+C or click Done in the browser to close.")

	go openBrowser(url)

	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, syscall.SIGINT, syscall.SIGTERM)
	select {
	case <-sigCh:
	case <-shutdown:
	}

	fmt.Println("\nClosing achievement browser...")
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()
	return srv.Shutdown(ctx)
}
