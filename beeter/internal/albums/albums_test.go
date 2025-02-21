package albums

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func setupTestDir(t *testing.T) (string, func()) {
	tmpDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}

	cleanup := func() {
		os.RemoveAll(tmpDir)
	}

	return tmpDir, cleanup
}

func createAlbumDir(t *testing.T, baseDir, name string, mtime time.Time) {
	path := filepath.Join(baseDir, name)
	if err := os.MkdirAll(path, 0755); err != nil {
		t.Fatalf("Failed to create album directory %s: %v", name, err)
	}
	if err := os.Chtimes(path, mtime, mtime); err != nil {
		t.Fatalf("Failed to set mtime for %s: %v", name, err)
	}
}

func TestNew(t *testing.T) {
	tmpDir, cleanup := setupTestDir(t)
	defer cleanup()

	tests := []struct {
		name      string
		albumsDir string
		wantErr   bool
	}{
		{
			name:      "valid directory",
			albumsDir: tmpDir,
			wantErr:   false,
		},
		{
			name:      "non-existent directory",
			albumsDir: filepath.Join(tmpDir, "nonexistent"),
			wantErr:   true,
		},
		{
			name:      "file instead of directory",
			albumsDir: filepath.Join(tmpDir, "file"),
			wantErr:   true,
		},
	}

	// Create a file for the "file instead of directory" test
	if err := os.WriteFile(filepath.Join(tmpDir, "file"), []byte("test"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			manager, err := New(tt.albumsDir)
			if (err != nil) != tt.wantErr {
				t.Errorf("New() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && manager == nil {
				t.Error("New() returned nil manager without error")
			}
		})
	}
}

func TestGetNewAlbums(t *testing.T) {
	tmpDir, cleanup := setupTestDir(t)
	defer cleanup()

	manager, err := New(tmpDir)
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}

	now := time.Now()
	oldTime := now.Add(-24 * time.Hour)

	// Create test albums
	createAlbumDir(t, tmpDir, "old_album", oldTime)
	createAlbumDir(t, tmpDir, "new_album", now)

	// Create a file (should be ignored)
	if err := os.WriteFile(filepath.Join(tmpDir, "test.txt"), []byte("test"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	tests := []struct {
		name    string
		since   time.Time
		want    int // number of albums expected
		wantErr bool
	}{
		{
			name:    "find new albums",
			since:   oldTime,
			want:    1,
			wantErr: false,
		},
		{
			name:    "find all albums",
			since:   oldTime.Add(-24 * time.Hour),
			want:    2,
			wantErr: false,
		},
		{
			name:    "find no albums",
			since:   now.Add(time.Hour),
			want:    0,
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			albums, err := manager.GetNewAlbums(tt.since)
			if (err != nil) != tt.wantErr {
				t.Errorf("GetNewAlbums() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if len(albums) != tt.want {
				t.Errorf("GetNewAlbums() got %v albums, want %v", len(albums), tt.want)
			}
		})
	}
}

func TestGetAlbumMtime(t *testing.T) {
	tmpDir, cleanup := setupTestDir(t)
	defer cleanup()

	manager, err := New(tmpDir)
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}

	now := time.Now().Truncate(time.Second)
	createAlbumDir(t, tmpDir, "test_album", now)

	// Create a file (not a directory)
	if err := os.WriteFile(filepath.Join(tmpDir, "not_a_dir"), []byte("test"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	tests := []struct {
		name    string
		dirName string
		want    time.Time
		wantErr bool
	}{
		{
			name:    "existing album",
			dirName: "test_album",
			want:    now,
			wantErr: false,
		},
		{
			name:    "non-existent album",
			dirName: "nonexistent",
			want:    time.Time{},
			wantErr: true,
		},
		{
			name:    "not a directory",
			dirName: "not_a_dir",
			want:    time.Time{},
			wantErr: true,
		},
		{
			name:    "path with parent traversal",
			dirName: "../test_album",
			want:    time.Time{},
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			mtime, err := manager.GetAlbumMtime(tt.dirName)
			if (err != nil) != tt.wantErr {
				t.Errorf("GetAlbumMtime() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && !mtime.Equal(tt.want) {
				t.Errorf("GetAlbumMtime() = %v, want %v", mtime, tt.want)
			}
		})
	}
}

func TestValidateAlbumPath(t *testing.T) {
	tmpDir, cleanup := setupTestDir(t)
	defer cleanup()

	manager, err := New(tmpDir)
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}

	// Create test directories and files
	createAlbumDir(t, tmpDir, "valid_album", time.Now())
	if err := os.WriteFile(filepath.Join(tmpDir, "not_a_dir"), []byte("test"), 0644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	tests := []struct {
		name    string
		dirName string
		wantErr bool
	}{
		{
			name:    "valid album",
			dirName: "valid_album",
			wantErr: false,
		},
		{
			name:    "non-existent album",
			dirName: "nonexistent",
			wantErr: true,
		},
		{
			name:    "not a directory",
			dirName: "not_a_dir",
			wantErr: true,
		},
		{
			name:    "path with parent traversal",
			dirName: "../valid_album",
			wantErr: true,
		},
		{
			name:    "absolute path",
			dirName: "/absolute/path",
			wantErr: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := manager.ValidateAlbumPath(tt.dirName)
			if (err != nil) != tt.wantErr {
				t.Errorf("ValidateAlbumPath() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
