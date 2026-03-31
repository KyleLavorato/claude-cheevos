package selfpatch

import (
	"encoding/hex"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestEnsureLibShSecret(t *testing.T) {
	tests := []struct {
		name           string
		initialContent string
		hmacSecret     []byte
		wantPatched    bool
		wantSecret     string
	}{
		{
			name: "already up to date",
			initialContent: `#!/usr/bin/env bash
_CHEEVOS_HMAC_SECRET="aabbccdd"
echo "test"
`,
			hmacSecret:  []byte{0xaa, 0xbb, 0xcc, 0xdd},
			wantPatched: false,
			wantSecret:  "aabbccdd",
		},
		{
			name: "needs patching",
			initialContent: `#!/usr/bin/env bash
_CHEEVOS_HMAC_SECRET="oldvalue"
echo "test"
`,
			hmacSecret:  []byte{0xaa, 0xbb, 0xcc, 0xdd},
			wantPatched: true,
			wantSecret:  "aabbccdd",
		},
		{
			name: "empty secret needs patching",
			initialContent: `#!/usr/bin/env bash
_CHEEVOS_HMAC_SECRET=""
echo "test"
`,
			hmacSecret:  []byte{0x11, 0x22, 0x33, 0x44},
			wantPatched: true,
			wantSecret:  "11223344",
		},
		{
			name: "no secret line present",
			initialContent: `#!/usr/bin/env bash
echo "test"
`,
			hmacSecret:  []byte{0xaa, 0xbb, 0xcc, 0xdd},
			wantPatched: false, // Can't patch if line doesn't exist
			wantSecret:  "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Create temp dir structure
			tmpDir := t.TempDir()
			scriptsDir := filepath.Join(tmpDir, "scripts")
			if err := os.MkdirAll(scriptsDir, 0755); err != nil {
				t.Fatal(err)
			}

			libShPath := filepath.Join(scriptsDir, "lib.sh")
			if err := os.WriteFile(libShPath, []byte(tt.initialContent), 0644); err != nil {
				t.Fatal(err)
			}

			// Run the patch function
			EnsureLibShSecret(tmpDir, tt.hmacSecret)

			// Read the result
			result, err := os.ReadFile(libShPath)
			if err != nil {
				t.Fatal(err)
			}

			// Check if secret was updated
			resultStr := string(result)
			if tt.wantSecret != "" {
				expectedLine := `_CHEEVOS_HMAC_SECRET="` + tt.wantSecret + `"`
				if !strings.Contains(resultStr, expectedLine) {
					t.Errorf("Expected secret line not found.\nWant: %s\nGot:\n%s", expectedLine, resultStr)
				}
			}

			// Verify the rest of the file is preserved
			if !strings.Contains(resultStr, "#!/usr/bin/env bash") {
				t.Error("Shebang line was lost")
			}
			if strings.Contains(tt.initialContent, "echo") && !strings.Contains(resultStr, "echo") {
				t.Error("Other content was lost")
			}
		})
	}
}

func TestEnsureLibShSecret_EmptyHmacSecret(t *testing.T) {
	// Should be a no-op if hmacSecret is empty
	tmpDir := t.TempDir()
	scriptsDir := filepath.Join(tmpDir, "scripts")
	if err := os.MkdirAll(scriptsDir, 0755); err != nil {
		t.Fatal(err)
	}

	libShPath := filepath.Join(scriptsDir, "lib.sh")
	content := `#!/usr/bin/env bash
_CHEEVOS_HMAC_SECRET="test"
`
	if err := os.WriteFile(libShPath, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	// Call with empty secret
	EnsureLibShSecret(tmpDir, []byte{})

	// Should be unchanged
	result, err := os.ReadFile(libShPath)
	if err != nil {
		t.Fatal(err)
	}

	if string(result) != content {
		t.Error("File was modified when it should not have been")
	}
}

func TestEnsureLibShSecret_FileNotFound(t *testing.T) {
	// Should fail silently if lib.sh doesn't exist
	tmpDir := t.TempDir()

	// Call with non-existent file - should not panic or error
	EnsureLibShSecret(tmpDir, []byte{0xaa, 0xbb})
}

func TestEnsureLibShSecret_PreservesFormatting(t *testing.T) {
	tmpDir := t.TempDir()
	scriptsDir := filepath.Join(tmpDir, "scripts")
	if err := os.MkdirAll(scriptsDir, 0755); err != nil {
		t.Fatal(err)
	}

	libShPath := filepath.Join(scriptsDir, "lib.sh")
	content := `#!/usr/bin/env bash
# Comment line
_CHEEVOS_HMAC_SECRET="oldvalue"
# Another comment

function test() {
    echo "hello"
}
`
	if err := os.WriteFile(libShPath, []byte(content), 0644); err != nil {
		t.Fatal(err)
	}

	newSecret := []byte{0xde, 0xad, 0xbe, 0xef}
	EnsureLibShSecret(tmpDir, newSecret)

	result, err := os.ReadFile(libShPath)
	if err != nil {
		t.Fatal(err)
	}

	resultStr := string(result)

	// Check that the secret was updated
	expectedSecret := hex.EncodeToString(newSecret)
	if !strings.Contains(resultStr, `_CHEEVOS_HMAC_SECRET="`+expectedSecret+`"`) {
		t.Error("Secret was not updated correctly")
	}

	// Check that other content is preserved
	if !strings.Contains(resultStr, "# Comment line") {
		t.Error("Comment was lost")
	}
	if !strings.Contains(resultStr, "function test()") {
		t.Error("Function was lost")
	}
	if !strings.Contains(resultStr, "# Another comment") {
		t.Error("Another comment was lost")
	}
}
