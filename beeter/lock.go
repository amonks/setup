package beeter

import (
	"fmt"
	"os"
	"path/filepath"
	"syscall"
)

// LockManager handles process locking to ensure only one instance runs at a time
type LockManager struct {
	lockPath string
	lockFile *os.File
}

// NewLockManager creates a new lock manager for the given data directory
func NewLockManager(dataDir string) *LockManager {
	return &LockManager{
		lockPath: filepath.Join(dataDir, "lock"),
	}
}

// AcquireLock attempts to acquire the lock file
// Returns nil if successful, error otherwise
func (l *LockManager) AcquireLock() error {
	fmt.Printf("Acquiring lock at %s\n", l.lockPath)
	var err error
	l.lockFile, err = os.OpenFile(l.lockPath, os.O_CREATE|os.O_RDWR, 0600)
	if err != nil {
		return fmt.Errorf("failed to open lock file: %w", err)
	}

	// Try to acquire an exclusive lock
	err = syscall.Flock(int(l.lockFile.Fd()), syscall.LOCK_EX|syscall.LOCK_NB)
	if err != nil {
		l.lockFile.Close()
		if err == syscall.EWOULDBLOCK {
			return fmt.Errorf("another instance is already running")
		}
		return fmt.Errorf("failed to acquire lock: %w", err)
	}

	return nil
}

// ReleaseLock releases the lock file
func (l *LockManager) ReleaseLock() error {
	if l.lockFile == nil {
		fmt.Printf("Lock file not found at %s\n", l.lockPath)
		return nil
	}
	fmt.Printf("Releasing lock at %s\n", l.lockPath)

	// Release the lock and close the file
	err := syscall.Flock(int(l.lockFile.Fd()), syscall.LOCK_UN)
	if err != nil {
		l.lockFile.Close()
		return fmt.Errorf("failed to release lock: %w", err)
	}

	if err := l.lockFile.Close(); err != nil {
		return fmt.Errorf("failed to close lock file: %w", err)
	}

	l.lockFile = nil
	return nil
}
