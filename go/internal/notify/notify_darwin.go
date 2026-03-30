//go:build darwin

package notify

import (
    "fmt"
    "os/exec"
    "strings"
)

// Send fires a macOS desktop notification using osascript.
func Send(title, body string) error {
    // Escape double-quotes for AppleScript string literals.
    title = strings.ReplaceAll(title, `"`, `\"`)
    body = strings.ReplaceAll(body, `"`, `\"`)
    script := fmt.Sprintf(
        `display notification "%s" with title "%s" sound name "Glass"`,
        body, title,
    )
    return exec.Command("osascript", "-e", script).Run()
}
