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
