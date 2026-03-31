package update

import (
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"
)

// Release represents a GitHub release from the API.
type Release struct {
	TagName string  `json:"tag_name"`
	Assets  []Asset `json:"assets"`
}

// Asset represents a downloadable asset from a GitHub release.
type Asset struct {
	Name               string `json:"name"`
	BrowserDownloadURL string `json:"browser_download_url"`
}

// FetchLatestRelease fetches the latest release from a GitHub repository.
// The repo parameter should be in the format "owner/repo".
func FetchLatestRelease(repo string) (*Release, error) {
	url := fmt.Sprintf("https://api.github.com/repos/%s/releases/latest", repo)
	client := &http.Client{Timeout: 10 * time.Second}

	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch release: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	var release Release
	if err := json.NewDecoder(resp.Body).Decode(&release); err != nil {
		return nil, fmt.Errorf("failed to decode release JSON: %w", err)
	}

	return &release, nil
}

// DownloadAsset downloads data from the given URL with a timeout.
func DownloadAsset(url string, timeout time.Duration) ([]byte, error) {
	client := &http.Client{Timeout: timeout}

	resp, err := client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to download: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("unexpected status code: %d", resp.StatusCode)
	}

	data, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	return data, nil
}

// VerifySHA256 verifies that the given data matches the expected SHA256 hash.
// The expectedHash should be a hex-encoded string.
func VerifySHA256(data []byte, expectedHash string) error {
	hash := sha256.Sum256(data)
	actualHash := hex.EncodeToString(hash[:])

	if actualHash != expectedHash {
		return fmt.Errorf("checksum mismatch: expected %s, got %s", expectedHash, actualHash)
	}

	return nil
}

// ParseSHA256Sums parses a SHA256SUMS file and returns a map of filename to hash.
// The format is the standard output of sha256sum: "hash  filename"
func ParseSHA256Sums(data []byte) (map[string]string, error) {
	result := make(map[string]string)

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		// Format: "hash  filename" (two spaces)
		parts := strings.Fields(line)
		if len(parts) < 2 {
			continue
		}

		hash := parts[0]
		filename := parts[1]
		result[filename] = hash
	}

	return result, nil
}

// FindAsset finds an asset in the release by name.
func FindAsset(release *Release, name string) (*Asset, error) {
	for _, asset := range release.Assets {
		if asset.Name == name {
			return &asset, nil
		}
	}
	return nil, fmt.Errorf("asset not found: %s", name)
}
