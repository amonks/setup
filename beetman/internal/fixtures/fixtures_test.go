package fixtures

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func setupTestDir(t *testing.T) (string, func()) {
	tmpDir, err := os.MkdirTemp("", "fixtures-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}

	cleanup := func() {
		os.RemoveAll(tmpDir)
	}

	return tmpDir, cleanup
}

func TestCreateTestAlbums(t *testing.T) {
	tmpDir, cleanup := setupTestDir(t)
	defer cleanup()

	testAlbums := []string{
		"album1",
		"album2",
		"nested/album3",
	}

	CreateTestAlbums(t, tmpDir, time.Now(), testAlbums...)

	// Verify all albums were created
	for _, album := range testAlbums {
		path := filepath.Join(tmpDir, album)
		if info, err := os.Stat(path); err != nil {
			t.Errorf("Album %s not created: %v", album, err)
		} else if !info.IsDir() {
			t.Errorf("Album %s is not a directory", album)
		}
	}
}
