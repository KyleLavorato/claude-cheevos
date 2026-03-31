package subcmd

import (
	"archive/zip"
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"time"

	"github.com/user/claude-cheevos/internal/defs"
	"github.com/user/claude-cheevos/internal/engine"
	"github.com/user/claude-cheevos/internal/lock"
	"github.com/user/claude-cheevos/internal/notify"
	"github.com/user/claude-cheevos/internal/store"
	"github.com/user/claude-cheevos/internal/update"
)

const (
	githubRepo           = "KyleLavorato/claude-cheevos"
	binaryUpdateInterval = 86400 // 24 hours
)

// UpdateBinary checks GitHub for a new binary release, downloads it,
// verifies the SHA256 checksum, and atomically replaces the current binary.
// It performs automatic rollback if the new binary fails a sanity check.
//
// Exits silently (no error) on network failure, if checked within the last 24h,
// if the opt-out file exists, or if this is a custom compilation (appVersion == "dev").
func UpdateBinary(achievementsDir string, appVersion string, force bool, key [32]byte) error {
	// Custom compilations never auto-update (even with --force)
	if appVersion == "dev" {
		return nil // Custom build - binary updates disabled
	}

	// Check for opt-out file
	noAutoUpdate := filepath.Join(achievementsDir, ".no-auto-update")
	if _, err := os.Stat(noAutoUpdate); err == nil {
		return nil // User has opted out
	}

	// Rate-limit check: read last_binary_update_check_epoch from state
	stateFile := filepath.Join(achievementsDir, "state.json")
	st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
	if err != nil {
		return nil
	}

	now := time.Now().Unix()
	if !force && now-st.LastBinaryUpdateCheckEpoch < binaryUpdateInterval {
		return nil // checked recently — exit silently
	}

	// Fetch latest release from GitHub
	release, err := update.FetchLatestRelease(githubRepo)
	if err != nil {
		return nil // network unavailable — exit silently
	}

	// Compare versions - exit if already up to date
	if release.TagName == appVersion {
		// Still update the timestamp so we don't keep checking
		if err := recordBinaryUpdateCheck(achievementsDir, now, appVersion, key); err != nil {
			return nil
		}
		return nil
	}

	// Detect platform
	platform := fmt.Sprintf("%s-%s", runtime.GOOS, runtime.GOARCH)
	zipName := fmt.Sprintf("claude-cheevos-%s.zip", platform)

	// Find the zip and SHA256SUMS assets
	zipAsset, err := update.FindAsset(release, zipName)
	if err != nil {
		return nil // Platform not supported or asset not found
	}

	sumsAsset, err := update.FindAsset(release, "SHA256SUMS")
	if err != nil {
		return nil // No checksums available
	}

	// Download SHA256SUMS
	sumsData, err := update.DownloadAsset(sumsAsset.BrowserDownloadURL, 10*time.Second)
	if err != nil {
		return nil // Download failed
	}

	checksums, err := update.ParseSHA256Sums(sumsData)
	if err != nil {
		return nil // Invalid checksums file
	}

	expectedHash, ok := checksums[zipName]
	if !ok {
		return nil // Checksum not found for this platform
	}

	// Download the zip file
	zipData, err := update.DownloadAsset(zipAsset.BrowserDownloadURL, 30*time.Second)
	if err != nil {
		return nil // Download failed
	}

	// Verify SHA256 checksum
	if err := update.VerifySHA256(zipData, expectedHash); err != nil {
		return nil // Checksum mismatch - corrupted download or MITM
	}

	// Extract binary from zip
	binaryName := "cheevos"
	if runtime.GOOS == "windows" {
		binaryName = "cheevos.exe"
	}
	platformBinaryName := fmt.Sprintf("cheevos-%s", platform)
	if runtime.GOOS == "windows" {
		platformBinaryName += ".exe"
	}

	binaryData, err := extractBinaryFromZip(zipData, platformBinaryName)
	if err != nil {
		return nil // Failed to extract binary
	}

	// Write to temp file in achievementsDir
	tmpFile, err := os.CreateTemp(achievementsDir, ".update_tmp_")
	if err != nil {
		return nil
	}
	tmpPath := tmpFile.Name()
	defer os.Remove(tmpPath) // Clean up on error

	if _, err := tmpFile.Write(binaryData); err != nil {
		tmpFile.Close()
		return nil
	}
	tmpFile.Close()

	// Set executable bit
	if err := os.Chmod(tmpPath, 0755); err != nil {
		return nil
	}

	// Sanity check: try to run `cheevos version` with new binary
	cmd := exec.Command(tmpPath, "version")
	if err := cmd.Run(); err != nil {
		return nil // New binary is broken - don't install it
	}

	// Backup current binary
	currentBinary := filepath.Join(achievementsDir, binaryName)
	backupBinary := filepath.Join(achievementsDir, binaryName+".bak")

	// On Windows, we need a different strategy since we can't replace a running exe
	if runtime.GOOS == "windows" {
		oldBinary := filepath.Join(achievementsDir, binaryName+".old_"+fmt.Sprint(time.Now().Unix()))
		if err := os.Rename(currentBinary, oldBinary); err != nil {
			return nil
		}
		if err := os.Rename(tmpPath, currentBinary); err != nil {
			// Rollback
			os.Rename(oldBinary, currentBinary)
			return nil
		}
		// Clean up old binary
		os.Remove(oldBinary)
	} else {
		// Unix: backup and atomic replace
		if err := os.Rename(currentBinary, backupBinary); err != nil {
			return nil
		}
		if err := os.Rename(tmpPath, currentBinary); err != nil {
			// Rollback
			os.Rename(backupBinary, currentBinary)
			return nil
		}
	}

	// Record the update in state
	if err := recordBinaryUpdateCheck(achievementsDir, now, release.TagName, key); err != nil {
		return nil
	}

	// Enqueue notification
	_ = notify.Send("🔄 Claude Cheevos Updated", fmt.Sprintf("Updated to %s", release.TagName))
	fmt.Fprintf(os.Stderr, "cheevos: updated to %s\n", release.TagName)

	return nil
}

// extractBinaryFromZip extracts a specific file from a zip archive.
func extractBinaryFromZip(zipData []byte, filename string) ([]byte, error) {
	reader := bytes.NewReader(zipData)
	zipReader, err := zip.NewReader(reader, int64(len(zipData)))
	if err != nil {
		return nil, err
	}

	// Look for the file in dist/ directory (as created by make dist-zip)
	targetPath := filepath.Join("dist", filename)

	for _, file := range zipReader.File {
		if file.Name == targetPath || file.Name == filename {
			rc, err := file.Open()
			if err != nil {
				return nil, err
			}
			defer rc.Close()

			data, err := io.ReadAll(rc)
			if err != nil {
				return nil, err
			}
			return data, nil
		}
	}

	return nil, fmt.Errorf("binary %s not found in zip", filename)
}

// recordBinaryUpdateCheck updates the state with the binary update check timestamp.
func recordBinaryUpdateCheck(achievementsDir string, timestamp int64, version string, key [32]byte) error {
	stateFile := filepath.Join(achievementsDir, "state.json")
	lockFile := filepath.Join(achievementsDir, "state.lock")

	l := lock.New(lockFile)
	if err := l.Lock(5 * time.Second); err != nil {
		return err
	}
	defer l.Unlock()

	// Re-load state to get freshest data
	st, err := store.NewEncryptedJSONStore(stateFile, key).Load()
	if err != nil {
		return err
	}

	// Update timestamp and version
	params := engine.UpdateParams{
		CounterUpdates:         map[string]int64{},
		BinaryUpdateCheckEpoch: timestamp,
		InstalledVersion:       version,
	}

	// Load definitions (needed by engine.Update even though we're not checking achievements)
	d, err := defs.Load(achievementsDir)
	if err != nil {
		return err
	}

	engine.Update(st, d, params)
	return store.NewEncryptedJSONStore(stateFile, key).Save(st)
}
