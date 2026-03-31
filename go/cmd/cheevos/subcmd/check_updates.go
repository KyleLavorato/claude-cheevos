package subcmd

// CheckUpdates runs both update-defs and update-binary sequentially.
// This is the entry point called by the session-start hook.
func CheckUpdates(achievementsDir string, appVersion string, force bool, key [32]byte) error {
	// First check for definition updates
	if err := UpdateDefs(achievementsDir, force, key); err != nil {
		// Continue to binary update even if defs update fails
		// (both are best-effort)
	}

	// Then check for binary updates
	if err := UpdateBinary(achievementsDir, appVersion, force, key); err != nil {
		// Fail silently - this is a best-effort update
	}

	return nil
}
