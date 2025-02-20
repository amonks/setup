package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"beeter/internal/mockbeet"
)

var binaryPath string

func TestMain(m *testing.M) {
	// Build the binary
	tmpDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		panic(err)
	}
	defer os.RemoveAll(tmpDir)

	binaryPath = filepath.Join(tmpDir, "beet-import-manager")
	cmd := exec.Command("go", "build", "-o", binaryPath)
	if err := cmd.Run(); err != nil {
		panic(err)
	}

	os.Exit(m.Run())
}

// testEnv holds test environment paths
type testEnv struct {
	homeDir   string
	dataDir   string
	albumsDir string
}

// setupTestEnv creates a test environment with necessary directories
func setupTestEnv(t *testing.T) *testEnv {
	t.Helper()

	// Create temporary home directory
	homeDir, err := os.MkdirTemp("", "beet-import-manager-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp home dir: %v", err)
	}

	// Create test directories
	dataDir := filepath.Join(homeDir, "data")
	albumsDir := filepath.Join(homeDir, "flac")

	// Create data and flac directories
	if err := os.MkdirAll(dataDir, 0755); err != nil {
		os.RemoveAll(homeDir)
		t.Fatalf("Failed to create data dir: %v", err)
	}
	if err := os.MkdirAll(albumsDir, 0755); err != nil {
		os.RemoveAll(homeDir)
		t.Fatalf("Failed to create flac dir: %v", err)
	}

	// Set HOME for this test
	os.Setenv("HOME", homeDir)

	return &testEnv{
		homeDir:   homeDir,
		dataDir:   dataDir,
		albumsDir: albumsDir,
	}
}

// cleanup removes the test environment
func (e *testEnv) cleanup() {
	os.RemoveAll(e.homeDir)
}

func runBinary(home string, args ...string) (string, error) {
	cmd := exec.Command(binaryPath, args...)
	var stdout, stderr bytes.Buffer
	cmd.Stdout = &stdout
	cmd.Stderr = &stderr
	cmd.Env = append(os.Environ(), "HOME="+home)
	err := cmd.Run()
	return strings.TrimSpace(stderr.String()), err
}

func TestNoCommand(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Test with no arguments
	output, err := runBinary(env.homeDir)
	if err == nil {
		t.Error("Process ran with err == nil, want non-nil")
	} else if exitErr, ok := err.(*exec.ExitError); !ok || exitErr.ExitCode() != 1 {
		t.Errorf("Process exited with code %d, want 1", exitErr.ExitCode())
	}

	// Verify error message
	if !strings.Contains(output, "Error: no command provided") {
		t.Errorf("Expected error message about no command, got: %q", output)
	}
}

func TestUnknownCommand(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Test with unknown command
	output, err := runBinary(env.homeDir,
		"--data-dir", env.dataDir,
		"--flac-dir", env.albumsDir,
		"unknown")
	if err == nil {
		t.Error("Process ran with err == nil, want non-nil")
	} else if exitErr, ok := err.(*exec.ExitError); !ok || exitErr.ExitCode() != 1 {
		t.Errorf("Process exited with code %d, want 1", exitErr.ExitCode())
	}

	// Verify error message
	if !strings.Contains(output, "Error: unknown command: unknown") {
		t.Errorf("Expected error message about unknown command, got: %q", output)
	}
}

func TestSetupMissingFlags(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Test setup command without required flags
	output, err := runBinary(env.homeDir,
		"--data-dir", env.dataDir,
		"--flac-dir", env.albumsDir,
		"setup")
	if err == nil {
		t.Error("Process ran with err == nil, want non-nil")
	} else if exitErr, ok := err.(*exec.ExitError); !ok || exitErr.ExitCode() != 1 {
		t.Errorf("Process exited with code %d, want 1", exitErr.ExitCode())
	}

	// Verify error message
	if !strings.Contains(output, "Error: missing required flags") {
		t.Errorf("Expected error message about missing flags, got: %q", output)
	}
}

func TestSetupWithFlags(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Create test albums with different mtimes
	oldTime := time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC)
	newTime := time.Date(2024, 3, 1, 0, 0, 0, 0, time.UTC)
	cutoffTime := time.Date(2024, 2, 1, 0, 0, 0, 0, time.UTC)

	// Create test albums
	testAlbums := []string{
		"old_album",
		"old_skipped_album",
		"new_album",
	}
	for _, album := range testAlbums[:2] { // First two albums are old
		albumPath := filepath.Join(env.albumsDir, album)
		if err := os.MkdirAll(albumPath, 0755); err != nil {
			t.Fatalf("Failed to create album directory: %v", err)
		}
		if err := os.Chtimes(albumPath, oldTime, oldTime); err != nil {
			t.Fatalf("Failed to set album mtime: %v", err)
		}
	}
	// Create new album
	albumPath := filepath.Join(env.albumsDir, testAlbums[2])
	if err := os.MkdirAll(albumPath, 0755); err != nil {
		t.Fatalf("Failed to create album directory: %v", err)
	}
	if err := os.Chtimes(albumPath, newTime, newTime); err != nil {
		t.Fatalf("Failed to set album mtime: %v", err)
	}

	// Create previous log file with one skipped album
	logFile := filepath.Join(env.dataDir, "previous.log")
	logContent := fmt.Sprintf("skip %s; test skip condition\n", filepath.Join(env.albumsDir, "old_skipped_album"))
	if err := os.WriteFile(logFile, []byte(logContent), 0644); err != nil {
		t.Fatalf("Failed to create previous log: %v", err)
	}

	// Run setup command
	output, err := runBinary(env.homeDir,
		"--data-dir", env.dataDir,
		"--flac-dir", env.albumsDir,
		"setup",
		"--cutoff-time", cutoffTime.Format(time.RFC3339),
		"--previous-log", logFile)
	if err != nil {
		t.Errorf("Setup command failed: %v\nOutput: %s", err, output)
	}

	// Test invalid cutoff time
	output, err = runBinary(env.homeDir,
		"--data-dir", env.dataDir,
		"--flac-dir", env.albumsDir,
		"setup",
		"--cutoff-time", "invalid",
		"--previous-log", logFile)
	if err == nil {
		t.Error("Expected error for invalid cutoff time, got nil")
	}

	// Test non-existent log file
	output, err = runBinary(env.homeDir,
		"--data-dir", env.dataDir,
		"--flac-dir", env.albumsDir,
		"setup",
		"--cutoff-time", cutoffTime.Format(time.RFC3339),
		"--previous-log", "nonexistent.log")
	if err == nil {
		t.Error("Expected error for non-existent log file, got nil")
	}
}

func TestImportCommand(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Create test albums
	testAlbums := []string{
		"normal_album",
		"skip_this_album",
		"another_normal_album",
	}
	for _, album := range testAlbums {
		albumPath := filepath.Join(env.albumsDir, album)
		if err := os.MkdirAll(albumPath, 0755); err != nil {
			t.Fatalf("Failed to create album directory: %v", err)
		}
	}

	// Run import command with mock beet
	cleanup := mockbeet.Mock(t, env.dataDir)
	defer cleanup()
	output, err := runBinary(env.homeDir,
		"--data-dir", env.dataDir,
		"--flac-dir", env.albumsDir,
		"import")
	if err != nil {
		t.Errorf("Import command failed: %v\nOutput: %s", err, output)
	}
}

func TestHandleSkipsCommand(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Create test albums
	testAlbums := []string{
		"skipped_album1",
		"skipped_album2",
	}
	for _, album := range testAlbums {
		albumPath := filepath.Join(env.albumsDir, album)
		if err := os.MkdirAll(albumPath, 0755); err != nil {
			t.Fatalf("Failed to create album directory: %v", err)
		}
	}

	// First run setup to mark albums as skipped
	logFile := filepath.Join(env.dataDir, "previous.log")
	var logContent strings.Builder
	for _, album := range testAlbums {
		logContent.WriteString(fmt.Sprintf("skip %s; test skip condition\n", filepath.Join(env.albumsDir, album)))
	}
	if err := os.WriteFile(logFile, []byte(logContent.String()), 0644); err != nil {
		t.Fatalf("Failed to create previous log: %v", err)
	}

	// Run handle-skips command with mock beet
	cleanup := mockbeet.Mock(t, env.dataDir)
	defer cleanup()
	output, err := runBinary(env.homeDir,
		"--data-dir", env.dataDir,
		"--flac-dir", env.albumsDir,
		"handle-skips")
	if err != nil {
		t.Errorf("Handle-skips command failed: %v\nOutput: %s", err, output)
	}
}
