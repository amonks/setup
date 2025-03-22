package database

import (
	"os"
	"path/filepath"
	"testing"
	"time"
)

func TestDatabase(t *testing.T) {
	// Create a temporary directory for testing
	tmpDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create a new database
	db, err := New(tmpDir)
	if err != nil {
		t.Fatalf("Failed to create database: %v", err)
	}
	defer db.Close()

	// Verify the database file was created
	if _, err := os.Stat(filepath.Join(tmpDir, "db.sqlite")); os.IsNotExist(err) {
		t.Error("Database file was not created")
	}

	// Test adding a new album
	testTime := time.Now().UTC().Truncate(time.Second) // Truncate to avoid sub-second precision issues
	if err := db.AddNewAlbum("test_album", testTime); err != nil {
		t.Errorf("Failed to add new album: %v", err)
	}

	// Test getting latest mtime
	latestMtime, err := db.GetLatestMtime()
	if err != nil {
		t.Errorf("Failed to get latest mtime: %v", err)
	}
	if !latestMtime.Equal(testTime) {
		t.Errorf("Latest mtime = %v, want %v", latestMtime, testTime)
	}

	// Test getting pending albums
	pending, err := db.GetPendingAlbums()
	if err != nil {
		t.Errorf("Failed to get pending albums: %v", err)
	}
	if len(pending) != 1 || pending[0] != "test_album" {
		t.Errorf("Pending albums = %v, want [test_album]", pending)
	}

	// Test marking as imported
	if err := db.MarkAsImported("test_album"); err != nil {
		t.Errorf("Failed to mark album as imported: %v", err)
	}

	// Verify album is no longer pending
	pending, err = db.GetPendingAlbums()
	if err != nil {
		t.Errorf("Failed to get pending albums: %v", err)
	}
	if len(pending) != 0 {
		t.Errorf("Found %d pending albums after marking as imported, want 0", len(pending))
	}

	// Test marking as skipped
	if err := db.AddNewAlbum("skipped_album", testTime); err != nil {
		t.Errorf("Failed to add new album: %v", err)
	}
	if err := db.MarkAsSkipped("skipped_album"); err != nil {
		t.Errorf("Failed to mark album as skipped: %v", err)
	}

	// Verify album appears in skipped list
	skipped, err := db.GetSkippedAlbums()
	if err != nil {
		t.Errorf("Failed to get skipped albums: %v", err)
	}
	if len(skipped) != 1 || skipped[0] != "skipped_album" {
		t.Errorf("Skipped albums = %v, want [skipped_album]", skipped)
	}
}

func TestDatabaseConcurrentAccess(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create initial database
	db1, err := New(tmpDir)
	if err != nil {
		t.Fatalf("Failed to create first database connection: %v", err)
	}
	defer db1.Close()

	// Create second connection to same database
	db2, err := New(tmpDir)
	if err != nil {
		t.Fatalf("Failed to create second database connection: %v", err)
	}
	defer db2.Close()

	// Test concurrent operations
	testTime := time.Now().UTC()

	// Add album with first connection
	if err := db1.AddNewAlbum("concurrent_test", testTime); err != nil {
		t.Errorf("Failed to add album with first connection: %v", err)
	}

	// Verify album is visible in second connection
	pending, err := db2.GetPendingAlbums()
	if err != nil {
		t.Errorf("Failed to get pending albums from second connection: %v", err)
	}
	if len(pending) != 1 || pending[0] != "concurrent_test" {
		t.Errorf("Pending albums from second connection = %v, want [concurrent_test]", pending)
	}

	// Mark as imported with second connection
	if err := db2.MarkAsImported("concurrent_test"); err != nil {
		t.Errorf("Failed to mark as imported with second connection: %v", err)
	}

	// Verify status change is visible in first connection
	pending, err = db1.GetPendingAlbums()
	if err != nil {
		t.Errorf("Failed to get pending albums from first connection: %v", err)
	}
	if len(pending) != 0 {
		t.Errorf("Found %d pending albums in first connection after marking as imported, want 0", len(pending))
	}
}

func TestFailureCount(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	db, err := New(tmpDir)
	if err != nil {
		t.Fatalf("Failed to create database: %v", err)
	}
	defer db.Close()

	// Add a new album
	testTime := time.Now().UTC().Truncate(time.Second)
	albumName := "test_album_failure"
	if err := db.AddNewAlbum(albumName, testTime); err != nil {
		t.Errorf("Failed to add new album: %v", err)
	}

	// Check initial failure count
	count, err := db.GetFailureCount(albumName)
	if err != nil {
		t.Errorf("Failed to get failure count: %v", err)
	}
	if count != 0 {
		t.Errorf("Initial failure count = %d, want 0", count)
	}

	// Increment failure count
	if err := db.IncrementFailureCount(albumName); err != nil {
		t.Errorf("Failed to increment failure count: %v", err)
	}

	// Check incremented failure count
	count, err = db.GetFailureCount(albumName)
	if err != nil {
		t.Errorf("Failed to get failure count: %v", err)
	}
	if count != 1 {
		t.Errorf("Failure count after increment = %d, want 1", count)
	}
}

func TestGetAlbumStats(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	db, err := New(tmpDir)
	if err != nil {
		t.Fatalf("Failed to create database: %v", err)
	}
	defer db.Close()

	// Add albums with different statuses
	testTime := time.Now().UTC().Truncate(time.Second)
	db.AddNewAlbum("pending_album", testTime)
	db.MarkAsImported("pending_album")
	db.AddNewAlbum("skipped_album", testTime)
	db.MarkAsSkipped("skipped_album")
	db.AddNewAlbum("failed_album", testTime)
	db.MarkAsFailed("failed_album")

	stats, err := db.GetAlbumStats()
	if err != nil {
		t.Fatalf("Failed to get album stats: %v", err)
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

func TestUpdateStatusTimestamp(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	db, err := New(tmpDir)
	if err != nil {
		t.Fatalf("Failed to create database: %v", err)
	}
	defer db.Close()

	// Add a test album
	albumName := "timestamp_test_album"
	testTime := time.Now().UTC().Truncate(time.Second)
	if err := db.AddNewAlbum(albumName, testTime); err != nil {
		t.Errorf("Failed to add new album: %v", err)
	}

	// Mark as skipped to set initial status
	if err := db.MarkAsSkipped(albumName); err != nil {
		t.Errorf("Failed to mark album as skipped: %v", err)
	}

	// Record the current timestamp
	var initialImportTime string
	err = db.db.QueryRow("SELECT import_time FROM albums WHERE directory_name = ?", albumName).Scan(&initialImportTime)
	if err != nil {
		t.Fatalf("Failed to get initial import time: %v", err)
	}

	// Wait a bit to ensure timestamp difference
	time.Sleep(100 * time.Millisecond)

	// Update just the timestamp
	if err := db.UpdateStatusTimestamp(albumName); err != nil {
		t.Errorf("Failed to update status timestamp: %v", err)
	}

	// Verify timestamp was updated but status remains the same
	var status string
	var newImportTime string
	err = db.db.QueryRow("SELECT status, import_time FROM albums WHERE directory_name = ?", albumName).Scan(&status, &newImportTime)
	if err != nil {
		t.Fatalf("Failed to get updated album data: %v", err)
	}

	// Check status is still skipped
	if status != "skipped" {
		t.Errorf("Status changed to %q, expected 'skipped'", status)
	}

	// Check import_time was updated
	if newImportTime == initialImportTime {
		t.Errorf("Import time was not updated: before=%q, after=%q", initialImportTime, newImportTime)
	}
}
