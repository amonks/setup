package beet

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"

	"beeter/internal/fixtures"
	"beeter/internal/mockbeet"
)

func setupTestDir(t *testing.T) (string, string, func()) {
	tmpDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}

	// Create test albums directory
	albumsDir := filepath.Join(tmpDir, "files/flac")
	if err := os.MkdirAll(albumsDir, 0755); err != nil {
		t.Fatalf("Failed to create albums directory: %v", err)
	}

	cleanup := func() {
		os.RemoveAll(tmpDir)
	}

	return tmpDir, albumsDir, cleanup
}

func TestNew(t *testing.T) {
	tmpDir, albumsDir, cleanup := setupTestDir(t)
	defer cleanup()

	// Create a separate non-existent directory path
	nonExistentDir := filepath.Join(tmpDir, "nonexistent")

	tests := []struct {
		name      string
		tempDir   string
		albumsDir string
		wantErr   bool
	}{
		{
			name:      "valid directories",
			tempDir:   tmpDir,
			albumsDir: albumsDir,
			wantErr:   false,
		},
		{
			name:      "non-existent temp dir",
			tempDir:   filepath.Join(tmpDir, "nonexistent-temp"),
			albumsDir: albumsDir,
			wantErr:   false, // Should create the directory
		},
		{
			name:      "non-existent flac dir",
			tempDir:   tmpDir,
			albumsDir: nonExistentDir,
			wantErr:   true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager, err := New(tt.tempDir, tt.albumsDir)
			if (err != nil) != tt.wantErr {
				t.Errorf("New() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if err == nil {
				if manager.tempDir != tt.tempDir {
					t.Errorf("New() tempDir = %v, want %v", manager.tempDir, tt.tempDir)
				}
				if manager.parser == nil {
					t.Error("New() parser is nil")
				}
			}
		})
	}
}

func TestCleanupLogFile(t *testing.T) {
	tmpDir, albumsDir, cleanup := setupTestDir(t)
	defer cleanup()

	manager, err := New(tmpDir, albumsDir)
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}

	tests := []struct {
		name    string
		logPath string
		setup   func(string) error
		wantErr bool
	}{
		{
			name:    "new log file",
			logPath: filepath.Join(tmpDir, "new.log"),
			setup:   nil,
			wantErr: false,
		},
		{
			name:    "existing log file",
			logPath: filepath.Join(tmpDir, "existing.log"),
			setup: func(path string) error {
				return os.WriteFile(path, []byte("test"), 0644)
			},
			wantErr: false,
		},
		{
			name:    "nested log file",
			logPath: filepath.Join(tmpDir, "nested", "new.log"),
			setup:   nil,
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if tt.setup != nil {
				if err := tt.setup(tt.logPath); err != nil {
					t.Fatalf("Failed to setup test: %v", err)
				}
			}

			err := manager.cleanupLogFile(tt.logPath)
			if (err != nil) != tt.wantErr {
				t.Errorf("cleanupLogFile() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			// Verify directory exists
			if _, err := os.Stat(filepath.Dir(tt.logPath)); os.IsNotExist(err) {
				t.Error("cleanupLogFile() did not create directory")
			}

			// Verify log file does not exist
			if _, err := os.Stat(tt.logPath); !os.IsNotExist(err) {
				t.Error("cleanupLogFile() did not remove existing log file")
			}
		})
	}
}

func TestImportBatch(t *testing.T) {
	tmpDir, albumsDir, cleanup := setupTestDir(t)
	defer cleanup()

	fixtures.CreateTestAlbums(t, albumsDir, time.Now(),
		"normal_album",
		"skip_this_album",
		"another_normal_album",
		"error_album",
	)

	manager, err := New(tmpDir, albumsDir)
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}

	tests := []struct {
		name      string
		albums    []string
		wantSkips []string
		wantErr   bool
	}{
		{
			name: "mixed albums",
			albums: []string{
				"normal_album",
				"skip_this_album",
				"another_normal_album",
			},
			wantSkips: []string{"skip_this_album"},
			wantErr:   false,
		},
		{
			name: "all normal albums",
			albums: []string{
				"normal_album",
				"another_normal_album",
			},
			wantSkips: nil,
			wantErr:   false,
		},
		{
			name: "all skipped albums",
			albums: []string{
				"skip_this_album",
			},
			wantSkips: []string{"skip_this_album"},
			wantErr:   false,
		},
		{
			name: "error album",
			albums: []string{
				"error_album",
			},
			wantSkips: nil,
			wantErr:   true,
		},
		{
			name:      "empty batch",
			albums:    []string{},
			wantSkips: nil,
			wantErr:   false,
		},
		{
			name: "non-existent albums",
			albums: []string{
				"nonexistent",
			},
			wantSkips: []string{"nonexistent"},
			wantErr:   false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cleanup := mockbeet.Mock(t, tmpDir)
			defer cleanup()
			ctx := context.Background()
			skipped, err := manager.ImportBatch(ctx, tt.albums)
			if (err != nil) != tt.wantErr {
				t.Errorf("ImportBatch() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				if len(skipped) != len(tt.wantSkips) {
					t.Errorf("ImportBatch() got %v skips, want %v", len(skipped), len(tt.wantSkips))
					return
				}

				// Create maps for easy comparison
				gotMap := make(map[string]bool)
				for _, album := range skipped {
					gotMap[album] = true
				}
				for _, album := range tt.wantSkips {
					if !gotMap[album] {
						t.Errorf("ImportBatch() missing expected skip %q", album)
					}
				}
			}
		})
	}
}

func TestImportBatchInteractively(t *testing.T) {
	tmpDir, albumsDir, cleanup := setupTestDir(t)
	defer cleanup()

	fixtures.CreateTestAlbums(t, albumsDir, time.Now(),
		"skipped_album1",
		"skipped_album2",
	)

	manager, err := New(tmpDir, albumsDir)
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}

	// Test importing skipped albums
	tests := []struct {
		name    string
		albums  []string
		wantErr bool
	}{
		{
			name: "skipped albums",
			albums: []string{
				filepath.Join(albumsDir, "skipped_album1"),
				filepath.Join(albumsDir, "skipped_album2"),
			},
			wantErr: false,
		},
		{
			name:    "empty batch",
			albums:  []string{},
			wantErr: false,
		},
		{
			name:    "non-existent albums",
			albums:  []string{"nonexistent"},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cleanup := mockbeet.Mock(t, tmpDir)
			defer cleanup()
			ctx := context.Background()
			err := manager.ImportBatchInteractively(ctx, tt.albums)
			if (err != nil) != tt.wantErr {
				t.Errorf("ImportSkippedBatch() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
		})
	}
}

func TestRemove(t *testing.T) {
	tmpDir, albumsDir, cleanup := setupTestDir(t)
	defer cleanup()

	manager, err := New(tmpDir, albumsDir)
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}

	tests := []struct {
		name    string
		query   string
		wantErr bool
	}{
		{
			name:    "simple query",
			query:   "album:test",
			wantErr: false,
		},
		{
			name:    "empty query",
			query:   "",
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cleanup := mockbeet.Mock(t, tmpDir)
			defer cleanup()
			ctx := context.Background()
			err := manager.Remove(ctx, tt.query)
			if (err != nil) != tt.wantErr {
				t.Errorf("Remove() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
