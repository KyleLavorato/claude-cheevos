//go:build windows

package notify

import (
    "fmt"
    "os/exec"
    "strings"
)

// Send fires a Windows toast notification via PowerShell.
func Send(title, body string) error {
    // Escape single quotes for PowerShell.
    title = strings.ReplaceAll(title, "'", "''")
    body = strings.ReplaceAll(body, "'", "''")

    script := fmt.Sprintf(`
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] | Out-Null
$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
$xml.LoadXml('<toast><visual><binding template="ToastText02"><text id="1">%s</text><text id="2">%s</text></binding></visual></toast>')
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Claude Code Achievements').Show($toast)
`, title, body)

    return exec.Command("powershell.exe", "-NoProfile", "-NonInteractive", "-Command", script).Run()
}
