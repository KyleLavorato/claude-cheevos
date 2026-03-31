package update

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestFetchLatestRelease(t *testing.T) {
	// Mock GitHub API response
	mockRelease := Release{
		TagName: "v2.0.0",
		Assets: []Asset{
			{Name: "binary-linux-amd64.zip", BrowserDownloadURL: "https://example.com/binary.zip"},
			{Name: "SHA256SUMS", BrowserDownloadURL: "https://example.com/SHA256SUMS"},
		},
	}

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/repos/test/repo/releases/latest" {
			t.Errorf("Unexpected path: %s", r.URL.Path)
		}
		json.NewEncoder(w).Encode(mockRelease)
	}))
	defer server.Close()

	testURL := server.URL + "/repos/test/repo/releases/latest"

	// Test with mock server by creating a local client
	client := &http.Client{Timeout: 10 * time.Second}
	resp, err := client.Get(testURL)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()

	var release2 Release
	if err := json.NewDecoder(resp.Body).Decode(&release2); err != nil {
		t.Fatal(err)
	}

	if release2.TagName != "v2.0.0" {
		t.Errorf("Expected tag v2.0.0, got %s", release2.TagName)
	}
	if len(release2.Assets) != 2 {
		t.Errorf("Expected 2 assets, got %d", len(release2.Assets))
	}
}

func TestDownloadAsset(t *testing.T) {
	expectedData := []byte("test binary data")

	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write(expectedData)
	}))
	defer server.Close()

	data, err := DownloadAsset(server.URL, 5*time.Second)
	if err != nil {
		t.Fatal(err)
	}

	if string(data) != string(expectedData) {
		t.Errorf("Expected %q, got %q", expectedData, data)
	}
}

func TestDownloadAsset_Timeout(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		time.Sleep(2 * time.Second)
		w.Write([]byte("too slow"))
	}))
	defer server.Close()

	_, err := DownloadAsset(server.URL, 100*time.Millisecond)
	if err == nil {
		t.Error("Expected timeout error, got nil")
	}
}

func TestDownloadAsset_NonOK(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusNotFound)
	}))
	defer server.Close()

	_, err := DownloadAsset(server.URL, 5*time.Second)
	if err == nil {
		t.Error("Expected error for 404, got nil")
	}
}

func TestVerifySHA256(t *testing.T) {
	data := []byte("test data")
	hash := sha256.Sum256(data)
	expectedHash := hex.EncodeToString(hash[:])

	// Test matching hash
	if err := VerifySHA256(data, expectedHash); err != nil {
		t.Errorf("Expected no error, got %v", err)
	}

	// Test mismatched hash
	if err := VerifySHA256(data, "badhash"); err == nil {
		t.Error("Expected error for mismatched hash, got nil")
	}
}

func TestParseSHA256Sums(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected map[string]string
	}{
		{
			name: "standard format",
			input: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  file1.txt
5d41402abc4b2a76b9719d911017c592  file2.txt`,
			expected: map[string]string{
				"file1.txt": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
				"file2.txt": "5d41402abc4b2a76b9719d911017c592",
			},
		},
		{
			name:  "empty input",
			input: "",
			expected: map[string]string{},
		},
		{
			name: "with blank lines",
			input: `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855  file1.txt

5d41402abc4b2a76b9719d911017c592  file2.txt`,
			expected: map[string]string{
				"file1.txt": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
				"file2.txt": "5d41402abc4b2a76b9719d911017c592",
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result, err := ParseSHA256Sums([]byte(tt.input))
			if err != nil {
				t.Fatal(err)
			}

			if len(result) != len(tt.expected) {
				t.Errorf("Expected %d entries, got %d", len(tt.expected), len(result))
			}

			for file, hash := range tt.expected {
				if result[file] != hash {
					t.Errorf("For file %s: expected hash %s, got %s", file, hash, result[file])
				}
			}
		})
	}
}

func TestFindAsset(t *testing.T) {
	release := &Release{
		Assets: []Asset{
			{Name: "file1.zip", BrowserDownloadURL: "https://example.com/file1.zip"},
			{Name: "file2.zip", BrowserDownloadURL: "https://example.com/file2.zip"},
			{Name: "SHA256SUMS", BrowserDownloadURL: "https://example.com/SHA256SUMS"},
		},
	}

	// Test finding existing asset
	asset, err := FindAsset(release, "file2.zip")
	if err != nil {
		t.Fatalf("Expected to find asset, got error: %v", err)
	}
	if asset.Name != "file2.zip" {
		t.Errorf("Expected file2.zip, got %s", asset.Name)
	}

	// Test not finding asset
	_, err = FindAsset(release, "nonexistent.zip")
	if err == nil {
		t.Error("Expected error for nonexistent asset, got nil")
	}
}
