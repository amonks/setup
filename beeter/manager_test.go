package beeter_test

import (
	"beeter"
	"os"
	"path/filepath"
	"testing"
	"time"

	"beeter/internal/fixtures"
	"beeter/internal/mockbeet"
)

// testEnv holds test environment paths
type testEnv struct {
	tmpDir    string
	dataDir   string
	albumsDir string
	cleanupFn func()
}

// setupTestEnv creates a test environment with necessary directories
func setupTestEnv(t *testing.T) *testEnv {
	t.Helper()

	// Create temp directory
	tmpDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}

	// Create data directory
	dataDir := filepath.Join(tmpDir, "data")
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		os.RemoveAll(tmpDir)
		t.Fatalf("Failed to create data directory: %v", err)
	}

	// Create flac directory
	albumsDir := filepath.Join(tmpDir, "files/flac")
	if err := os.MkdirAll(albumsDir, 0755); err != nil {
		os.RemoveAll(tmpDir)
		t.Fatalf("Failed to create flac directory: %v", err)
	}

	return &testEnv{
		tmpDir:    tmpDir,
		dataDir:   dataDir,
		albumsDir: albumsDir,
		cleanupFn: func() {
			os.RemoveAll(tmpDir)
		},
	}
}

// cleanup removes the test environment
func (e *testEnv) cleanup() {
	e.cleanupFn()
}

func TestNew(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Create manager
	manager, err := beeter.New(beeter.Options{
		DataDir:   env.dataDir,
		AlbumsDir: env.albumsDir,
	})
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}
	defer manager.Close()

	// Verify data directory was created
	info, err := os.Stat(env.dataDir)
	if err != nil {
		t.Fatalf("Data directory was not created: %v", err)
	}
	if !info.IsDir() {
		t.Error("Data path is not a directory")
	}
	if info.Mode().Perm() != 0700 {
		t.Errorf("Data directory permissions = %v, want %v", info.Mode().Perm(), 0700)
	}

	// Verify lock file exists
	if _, err := os.Stat(filepath.Join(env.dataDir, "lock")); os.IsNotExist(err) {
		t.Error("Lock file was not created")
	}

	// Verify database file exists
	if _, err := os.Stat(filepath.Join(env.dataDir, "db.sqlite")); os.IsNotExist(err) {
		t.Error("Database file was not created")
	}

	// Verify temp directory exists
	if _, err := os.Stat(filepath.Join(env.dataDir, "tmp")); os.IsNotExist(err) {
		t.Error("Temp directory was not created")
	}
}

func TestNewConcurrent(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	opts := beeter.Options{
		DataDir:   env.dataDir,
		AlbumsDir: env.albumsDir,
	}

	// Create first manager
	manager1, err := beeter.New(opts)
	if err != nil {
		t.Fatalf("Failed to create first manager: %v", err)
	}
	defer manager1.Close()

	// Try to create second manager (should fail due to lock)
	manager2, err := beeter.New(opts)
	if err == nil {
		manager2.Close()
		t.Error("Expected error when creating second manager, got nil")
	}
}

func TestClose(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	opts := beeter.Options{
		DataDir:   env.dataDir,
		AlbumsDir: env.albumsDir,
	}

	// Create manager
	manager, err := beeter.New(opts)
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}

	// Close manager
	if err := manager.Close(); err != nil {
		t.Errorf("Failed to close manager: %v", err)
	}

	// Verify lock is released by trying to create new manager
	manager2, err := beeter.New(opts)
	if err != nil {
		t.Errorf("Failed to create new manager after close: %v", err)
	}
	defer manager2.Close()
}

func TestSetup(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Set mtimes
	oldTime := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	newTime := time.Date(2024, 3, 1, 0, 0, 0, 0, time.UTC)
	cutoffTime := time.Date(2024, 2, 1, 0, 0, 0, 0, time.UTC)

	// Create test albums
	fixtures.CreateTestAlbums(t, env.albumsDir, oldTime, "old_album")
	fixtures.CreateTestAlbums(t, env.albumsDir, oldTime, "old_skipped_album")
	fixtures.CreateTestAlbums(t, env.albumsDir, newTime, "new_album")

	// Create previous log file
	logFile := filepath.Join(env.dataDir, "previous.log")
	logContent := "skip " + filepath.Join(env.albumsDir, "old_skipped_album") + "; test skip condition\n"
	if err := os.WriteFile(logFile, []byte(logContent), 0644); err != nil {
		t.Fatalf("Failed to create previous log: %v", err)
	}

	// Create manager
	manager, err := beeter.New(beeter.Options{
		DataDir:   env.dataDir,
		AlbumsDir: env.albumsDir,
	})
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}
	defer manager.Close()

	// Run setup
	if err := manager.Setup(cutoffTime.Format(time.RFC3339), logFile); err != nil {
		t.Fatalf("Setup failed: %v", err)
	}

	// Verify database state
	tests := []struct {
		name      string
		getAlbums func() ([]string, error)
		want      []string
	}{
		{
			name:      "imported albums",
			getAlbums: manager.DB.GetImportedAlbums,
			want:      []string{"old_album"},
		},
		{
			name:      "skipped albums",
			getAlbums: manager.DB.GetSkippedAlbums,
			want:      []string{"old_skipped_album"},
		},
		{
			name:      "pending albums",
			getAlbums: manager.DB.GetPendingAlbums,
			want:      []string{"new_album"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := tt.getAlbums()
			if err != nil {
				t.Fatalf("Failed to get albums: %v", err)
			}

			// Create maps for comparison
			gotMap := make(map[string]bool)
			for _, album := range got {
				gotMap[album] = true
			}
			wantMap := make(map[string]bool)
			for _, album := range tt.want {
				wantMap[album] = true
			}

			// Compare results
			if len(got) != len(tt.want) {
				t.Errorf("Got %d albums, want %d", len(got), len(tt.want))
			}
			for _, album := range tt.want {
				if !gotMap[album] {
					t.Errorf("Missing album %s", album)
				}
			}
			for _, album := range got {
				if !wantMap[album] {
					t.Errorf("Unexpected album %s", album)
				}
			}
		})
	}

	// Test invalid cutoff time
	if err := manager.Setup("invalid", logFile); err == nil {
		t.Error("Expected error for invalid cutoff time, got nil")
	}

	// Test non-existent log file
	if err := manager.Setup(cutoffTime.Format(time.RFC3339), "nonexistent.log"); err == nil {
		t.Error("Expected error for non-existent log file, got nil")
	}
}

func TestImport(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	fixtures.CreateTestAlbums(t, env.albumsDir, time.Now(),
		"normal_album",
		"skip_this_album",
		"another_normal_album",
	)

	// Create manager
	manager, err := beeter.New(beeter.Options{
		DataDir:   env.dataDir,
		AlbumsDir: env.albumsDir,
	})
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}
	defer manager.Close()

	// Run import
	cleanup := mockbeet.Mock(t, env.dataDir)
	defer cleanup()
	if err := manager.Import(); err != nil {
		t.Fatalf("Import failed: %v", err)
	}

	// Verify database state
	tests := []struct {
		name      string
		getAlbums func() ([]string, error)
		want      []string
	}{
		{
			name: "imported albums",
			getAlbums: func() ([]string, error) {
				pending, err := manager.DB.GetPendingAlbums()
				if err != nil {
					return nil, err
				}
				return pending, nil
			},
			want: []string{},
		},
		{
			name: "skipped albums",
			getAlbums: func() ([]string, error) {
				skipped, err := manager.DB.GetSkippedAlbums()
				if err != nil {
					return nil, err
				}
				return skipped, nil
			},
			want: []string{"skip_this_album"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := tt.getAlbums()
			if err != nil {
				t.Fatalf("Failed to get albums: %v", err)
			}

			// Create maps for comparison
			gotMap := make(map[string]bool)
			for _, album := range got {
				gotMap[album] = true
			}
			wantMap := make(map[string]bool)
			for _, album := range tt.want {
				wantMap[album] = true
			}

			// Compare results
			if len(got) != len(tt.want) {
				t.Errorf("Got %d albums, want %d", len(got), len(tt.want))
			}
			for _, album := range tt.want {
				if !gotMap[album] {
					t.Errorf("Missing album %s", album)
				}
			}
			for _, album := range got {
				if !wantMap[album] {
					t.Errorf("Unexpected album %s", album)
				}
			}
		})
	}
}

func TestHandleSkips(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Create test albums
	testAlbums := []string{
		"skipped_album1",
		"skipped_album2",
	}
	fixtures.CreateTestAlbums(t, env.albumsDir, time.Now(), testAlbums...)

	// Create manager
	manager := CreateManager(t, env.dataDir, env.albumsDir)
	defer manager.Close()

	// Mark albums as skipped
	skippedPaths := make([]string, len(testAlbums))
	for i, album := range testAlbums {
		skippedPaths[i] = filepath.Join(env.albumsDir, album)
	}
	if err := manager.DB.MarkAsSkipped(skippedPaths...); err != nil {
		t.Fatalf("Failed to mark albums as skipped: %v", err)
	}

	// Run handle-skips
	cleanup := mockbeet.Mock(t, env.dataDir)
	defer cleanup()
	if err := manager.HandleSkips(); err != nil {
		t.Fatalf("HandleSkips failed: %v", err)
	}

	// Verify all albums are now imported
	skipped, err := manager.DB.GetSkippedAlbums()
	if err != nil {
		t.Fatalf("Failed to get skipped albums: %v", err)
	}
	if len(skipped) != 0 {
		t.Errorf("Found %d skipped albums after handle-skips, want 0", len(skipped))
	}
}

func TestHandleErrors(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Create test albums
	testAlbums := []string{
		"failed_album1",
		"failed_album2",
	}
	fixtures.CreateTestAlbums(t, env.albumsDir, time.Now(), testAlbums...)

	// Create manager
	manager := CreateManager(t, env.dataDir, env.albumsDir)
	defer manager.Close()

	// Mark albums as failed
	failedPaths := make([]string, len(testAlbums))
	for i, album := range testAlbums {
		failedPaths[i] = filepath.Join(env.albumsDir, album)
	}
	if err := manager.DB.MarkAsFailed(failedPaths...); err != nil {
		t.Fatalf("Failed to mark albums as failed: %v", err)
	}

	// Run handle-errors
	cleanup := mockbeet.Mock(t, env.dataDir)
	defer cleanup()
	if err := manager.HandleErrors(); err != nil {
		t.Fatalf("HandleErrors failed: %v", err)
	}

	// Verify all albums are now imported or skipped
	failed, err := manager.DB.GetFailedAlbums()
	if err != nil {
		t.Fatalf("Failed to get failed albums: %v", err)
	}
	if len(failed) != 0 {
		t.Errorf("Found %d failed albums after handle-errors, want 0", len(failed))
	}
}

func TestNewReadOnly(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Create read-only manager
	manager, err := beeter.NewReadOnly(beeter.Options{
		DataDir:   env.dataDir,
		AlbumsDir: env.albumsDir,
	})
	if err != nil {
		t.Fatalf("Failed to create read-only manager: %v", err)
	}
	defer manager.Close()

	// Verify data directory was created
	info, err := os.Stat(env.dataDir)
	if err != nil {
		t.Fatalf("Data directory was not created: %v", err)
	}
	if !info.IsDir() {
		t.Error("Data path is not a directory")
	}
	if info.Mode().Perm() != 0700 {
		t.Errorf("Data directory permissions = %v, want %v", info.Mode().Perm(), 0700)
	}

	// Verify lock file does NOT exist
	if _, err := os.Stat(filepath.Join(env.dataDir, "lock")); !os.IsNotExist(err) {
		t.Error("Lock file was created in read-only mode")
	}

	// Verify database file exists
	if _, err := os.Stat(filepath.Join(env.dataDir, "db.sqlite")); os.IsNotExist(err) {
		t.Error("Database file was not created")
	}

	// Test concurrent access with read-only manager
	manager2, err := beeter.NewReadOnly(beeter.Options{
		DataDir:   env.dataDir,
		AlbumsDir: env.albumsDir,
	})
	if err != nil {
		t.Fatalf("Failed to create second read-only manager: %v", err)
	}
	defer manager2.Close()
}

func TestStats(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// First create a regular manager to set up the data
	manager, err := beeter.New(beeter.Options{
		DataDir:   env.dataDir,
		AlbumsDir: env.albumsDir,
	})
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}

	// Add albums with different statuses
	testTime := time.Now().UTC().Truncate(time.Second)
	manager.DB.AddNewAlbum("pending_album", testTime)
	manager.DB.MarkAsImported("pending_album")
	manager.DB.AddNewAlbum("skipped_album", testTime)
	manager.DB.MarkAsSkipped("skipped_album")
	manager.DB.AddNewAlbum("failed_album", testTime)
	manager.DB.MarkAsFailed("failed_album")

	// Close the regular manager
	manager.Close()

	// Create a read-only manager to test stats
	roManager, err := beeter.NewReadOnly(beeter.Options{
		DataDir:   env.dataDir,
		AlbumsDir: env.albumsDir,
	})
	if err != nil {
		t.Fatalf("Failed to create read-only manager: %v", err)
	}
	defer roManager.Close()

	stats, err := roManager.Stats()
	if err != nil {
		t.Fatalf("Failed to get stats: %v", err)
	}

	expectedStats := map[string]int{
		"imported": 1,
		"skipped":  1,
		"failed":   1,
	}

	for status, expectedCount := range expectedStats {
		if count, ok := stats[status]; !ok || count != expectedCount {
			t.Errorf("Stats for %s = %d, want %d", status, count, expectedCount)
		}
	}
}

func CreateManager(t *testing.T, dataDir, albumsDir string) *beeter.BeetImportManager {
	t.Helper()
	manager, err := beeter.New(beeter.Options{
		DataDir:   dataDir,
		AlbumsDir: albumsDir,
	})
	if err != nil {
		t.Fatalf("Failed to create manager: %v", err)
	}
	return manager
}
