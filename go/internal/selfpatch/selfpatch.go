package selfpatch

import (
	"bufio"
	"encoding/hex"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// EnsureLibShSecret ensures that scripts/lib.sh contains the correct HMAC secret.
// This is necessary because when the binary is replaced during auto-update,
// the new binary has a different HMAC secret that must be injected into lib.sh.
//
// This function is best-effort and fails silently on any error, as it's a
// self-healing mechanism that shouldn't break normal operation.
func EnsureLibShSecret(achievementsDir string, hmacSecret []byte) {
	if len(hmacSecret) == 0 {
		return // No HMAC secret to patch
	}

	libShPath := filepath.Join(achievementsDir, "scripts", "lib.sh")

	// Read the current lib.sh file
	file, err := os.Open(libShPath)
	if err != nil {
		return // Fail silently
	}
	defer file.Close()

	var lines []string
	var currentSecret string
	secretLineIdx := -1

	scanner := bufio.NewScanner(file)
	lineNum := 0
	for scanner.Scan() {
		line := scanner.Text()
		lines = append(lines, line)

		// Look for the HMAC secret line
		if strings.HasPrefix(line, "_CHEEVOS_HMAC_SECRET=") {
			// Extract the current value
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				currentSecret = strings.Trim(parts[1], `"`)
				secretLineIdx = lineNum
			}
		}
		lineNum++
	}

	if err := scanner.Err(); err != nil {
		return // Fail silently
	}

	// Compare to expected secret
	expectedSecret := hex.EncodeToString(hmacSecret)
	if currentSecret == expectedSecret {
		return // Already up to date
	}

	// Need to patch - update the line
	if secretLineIdx >= 0 {
		lines[secretLineIdx] = fmt.Sprintf(`_CHEEVOS_HMAC_SECRET="%s"`, expectedSecret)
	} else {
		return // Secret line not found, fail silently
	}

	// Write back to file
	output := strings.Join(lines, "\n") + "\n"
	if err := os.WriteFile(libShPath, []byte(output), 0644); err != nil {
		return // Fail silently
	}
}
