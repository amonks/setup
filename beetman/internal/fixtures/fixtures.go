package fixtures

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

// CreateTestAlbums creates test album directories
func CreateTestAlbums(t *testing.T, baseDir string, mtime time.Time, albums ...string) {
	for _, album := range albums {
		albumPath := filepath.Join(baseDir, album)
		if err := os.MkdirAll(albumPath, 0755); err != nil {
			t.Fatalf("Failed to create test album %s: %v", album, err)
		}
		if err := os.Chtimes(albumPath, mtime, mtime); err != nil {
			t.Fatalf("Failed to set mtime for %s: %v", album, err)
		}
	}
}
