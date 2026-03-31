//go:build darwin

package notify

import (
    "fmt"
    "os"
    "os/exec"
    "path/filepath"
    "strings"
)

// Send fires a macOS desktop notification using osascript.
func Send(title, body string) error {
    return SendWithTier(title, body, "")
}

// SendWithTier sends a notification with a tier-specific icon using terminal-notifier.
// Falls back to osascript if terminal-notifier is unavailable or tier is empty.
func SendWithTier(title, body, tier string) error {
    // Check if terminal-notifier is available and tier is specified
    if _, err := exec.LookPath("terminal-notifier"); err == nil && tier != "" {
        homeDir, err := os.UserHomeDir()
        if err != nil {
            return fallbackOsascript(title, body)
        }

        iconPath := filepath.Join(homeDir, ".claude", "achievements", "data", "icons", tier+".png")
        if _, err := os.Stat(iconPath); err != nil {
            // Icon file doesn't exist, fall back
            return fallbackOsascript(title, body)
        }

        cmd := exec.Command("terminal-notifier",
            "-title", title,
            "-message", body,
            "-contentImage", iconPath,
            "-sound", "Glass",
        )
        return cmd.Run()
    }

    // Fallback to osascript
    return fallbackOsascript(title, body)
}

func fallbackOsascript(title, body string) error {
    // Escape double-quotes for AppleScript string literals.
    title = strings.ReplaceAll(title, `"`, `\"`)
    body = strings.ReplaceAll(body, `"`, `\"`)
    script := fmt.Sprintf(
        `display notification "%s" with title "%s" sound name "Glass"`,
        body, title,
    )
    return exec.Command("osascript", "-e", script).Run()
}
