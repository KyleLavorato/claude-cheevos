package subcmd

import (
	"os"
	"path/filepath"
	"testing"
)

func TestUpdateBinary_CustomCompilation(t *testing.T) {
	tmpDir := t.TempDir()
	var key [32]byte

	// Custom compilations (appVersion == "dev") should never auto-update
	err := UpdateBinary(tmpDir, "dev", false, key)
	if err != nil {
		t.Errorf("Expected no error for custom compilation, got %v", err)
	}

	// Even with --force
	err = UpdateBinary(tmpDir, "dev", true, key)
	if err != nil {
		t.Errorf("Expected no error for custom compilation with force, got %v", err)
	}
}

func TestUpdateBinary_OptOut(t *testing.T) {
	tmpDir := t.TempDir()
	var key [32]byte

	// Create opt-out file
	noAutoUpdate := filepath.Join(tmpDir, ".no-auto-update")
	if err := os.WriteFile(noAutoUpdate, []byte(""), 0644); err != nil {
		t.Fatal(err)
	}

	// Should exit silently without error
	err := UpdateBinary(tmpDir, "v1.0.0", false, key)
	if err != nil {
		t.Errorf("Expected no error with opt-out file, got %v", err)
	}
}

func TestUpdateBinary_NoState(t *testing.T) {
	tmpDir := t.TempDir()
	var key [32]byte

	// Should exit silently if state doesn't exist
	err := UpdateBinary(tmpDir, "v1.0.0", false, key)
	if err != nil {
		t.Errorf("Expected no error without state, got %v", err)
	}
}

func TestExtractBinaryFromZip(t *testing.T) {
	// This is tested indirectly through integration tests
	// For now, just verify the function signature exists
	_, err := extractBinaryFromZip([]byte("invalid zip"), "test")
	if err == nil {
		t.Error("Expected error for invalid zip data")
	}
}
