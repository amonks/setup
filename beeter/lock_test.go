package beeter

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLockManager(t *testing.T) {
	// Create a temporary directory for testing
	tmpDir := t.TempDir()

	// Create a new lock manager
	lockManager := NewLockManager(tmpDir)

	// Test acquiring lock
	if err := lockManager.AcquireLock(); err != nil {
		t.Errorf("Failed to acquire lock: %v", err)
	}

	// Verify lock file exists
	if _, err := os.Stat(filepath.Join(tmpDir, "lock")); os.IsNotExist(err) {
		t.Error("Lock file was not created")
	}

	// Test attempting to acquire lock when already held
	lockManager2 := NewLockManager(tmpDir)
	if err := lockManager2.AcquireLock(); err == nil {
		t.Error("Expected error when acquiring already held lock, got nil")
	}

	// Test releasing lock
	if err := lockManager.ReleaseLock(); err != nil {
		t.Errorf("Failed to release lock: %v", err)
	}

	// Test acquiring lock after release
	if err := lockManager2.AcquireLock(); err != nil {
		t.Errorf("Failed to acquire lock after release: %v", err)
	}

	// Clean up
	if err := lockManager2.ReleaseLock(); err != nil {
		t.Errorf("Failed to release second lock: %v", err)
	}
}

func TestLockManagerConcurrent(t *testing.T) {
	tmpDir, err := os.MkdirTemp("", "beet-lock-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tmpDir)

	// Create channels for synchronization
	acquired := make(chan bool)
	released := make(chan bool)
	done := make(chan bool)

	// Start first goroutine that holds the lock
	go func() {
		lockManager := NewLockManager(tmpDir)
		if err := lockManager.AcquireLock(); err != nil {
			t.Errorf("Failed to acquire lock in first goroutine: %v", err)
			acquired <- false
			return
		}
		acquired <- true

		// Hold the lock for a moment
		<-done

		t.Logf("Releasing lock in first goroutine")
		if err := lockManager.ReleaseLock(); err != nil {
			t.Errorf("Failed to release lock in first goroutine: %v", err)
		}
		released <- true
	}()

	// Wait for first goroutine to acquire lock
	if !<-acquired {
		t.Fatal("First goroutine failed to acquire lock")
	}

	// Try to acquire lock in second goroutine
	lockManager2 := NewLockManager(tmpDir)
	t.Logf("Acquiring lock in second goroutine (expecting failure)")
	if err := lockManager2.AcquireLock(); err == nil {
		t.Fatalf("Expected error when acquiring lock in second goroutine, got nil")
	}

	// Signal first goroutine to release lock
	t.Logf("Signaling first goroutine to release lock")
	done <- true

	// Wait for first goroutine to release lock
	<-released
	t.Logf("First goroutine should have released lock")

	// Now should be able to acquire lock
	t.Logf("Acquiring lock in second goroutine (expecting success)")
	if err := lockManager2.AcquireLock(); err != nil {
		t.Fatalf("Failed to acquire lock after release: %v", err)
	}

	// Clean up
	if err := lockManager2.ReleaseLock(); err != nil {
		t.Errorf("Failed to release lock at end of test: %v", err)
	}
}
