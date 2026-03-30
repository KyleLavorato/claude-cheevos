//go:build linux

package notify

import (
    "os/exec"
)

// Send fires a desktop notification using notify-send (if available).
// Silently succeeds if notify-send is not installed.
func Send(title, body string) error {
    if _, err := exec.LookPath("notify-send"); err != nil {
        return nil // notify-send not available; skip silently
    }
    return exec.Command("notify-send", title, body).Run()
}
