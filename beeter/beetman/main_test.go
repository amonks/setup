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

	"beeter"
	"beeter/internal/fixtures"
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
	albumsDir := filepath.Join(homeDir, "files/flac")

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
	if err != nil {
		return strings.TrimSpace(stderr.String()), err
	}
	return strings.TrimSpace(stdout.String()), err
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

func TestHandleErrorsCommand(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Create test albums
	testAlbums := []string{
		"failed_album1",
		"failed_album2",
	}
	for _, album := range testAlbums {
		albumPath := filepath.Join(env.albumsDir, album)
		if err := os.MkdirAll(albumPath, 0755); err != nil {
			t.Fatalf("Failed to create album directory: %v", err)
		}
	}

	// First run setup to mark albums as failed
	logFile := filepath.Join(env.dataDir, "previous.log")
	var logContent strings.Builder
	for _, album := range testAlbums {
		logContent.WriteString(fmt.Sprintf("fail %s; test fail condition\n", filepath.Join(env.albumsDir, album)))
	}
	if err := os.WriteFile(logFile, []byte(logContent.String()), 0644); err != nil {
		t.Fatalf("Failed to create previous log: %v", err)
	}

	// Run handle-errors command with mock beet
	cleanup := mockbeet.Mock(t, env.dataDir)
	defer cleanup()
	output, err := runBinary(env.homeDir,
		"--data-dir", env.dataDir,
		"--flac-dir", env.albumsDir,
		"handle-errors")
	if err != nil {
		t.Errorf("Handle-errors command failed: %v\nOutput: %s", err, output)
	}
}

// CreateManager creates a new manager instance for testing
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

func TestStatsCommand(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// Add albums with different statuses
	testTime := time.Now().UTC().Truncate(time.Second)
	runBinary(env.homeDir, "--data-dir", env.dataDir, "--flac-dir", env.albumsDir, "setup", "--cutoff-time", testTime.Format(time.RFC3339), "--previous-log", "")

	// Create test albums
	fixtures.CreateTestAlbums(t, env.albumsDir, testTime,
		"imported_album",
		"skipped_album",
		"failed_album",
	)

	// Mark albums with different statuses
	manager := CreateManager(t, env.dataDir, env.albumsDir)
	manager.DB.AddNewAlbum("imported_album", testTime)
	manager.DB.MarkAsImported("imported_album")
	manager.DB.AddNewAlbum("skipped_album", testTime)
	manager.DB.MarkAsSkipped("skipped_album")
	manager.DB.AddNewAlbum("failed_album", testTime)
	manager.DB.MarkAsFailed("failed_album")
	manager.Close()

	// Run stats command
	output, err := runBinary(env.homeDir, "--data-dir", env.dataDir, "--flac-dir", env.albumsDir, "stats")
	if err != nil {
		t.Fatalf("Stats command failed: %v", err)
	}

	// Verify output
	expectedOutputs := []string{"imported: 1", "skipped: 1", "failed: 1"}
	for _, expected := range expectedOutputs {
		if !strings.Contains(output, expected) {
			t.Errorf("Expected output to contain %q, got %q", expected, output)
		}
	}
}

func TestStatsConcurrent(t *testing.T) {
	env := setupTestEnv(t)
	defer env.cleanup()

	// First run setup to add some data
	testTime := time.Now().UTC().Truncate(time.Second)
	runBinary(env.homeDir, "--data-dir", env.dataDir, "--flac-dir", env.albumsDir, "setup", "--cutoff-time", testTime.Format(time.RFC3339), "--previous-log", "")

	// Create test albums and set their status
	manager := CreateManager(t, env.dataDir, env.albumsDir)
	manager.DB.AddNewAlbum("imported_album", testTime)
	manager.DB.MarkAsImported("imported_album")
	manager.DB.AddNewAlbum("skipped_album", testTime)
	manager.DB.MarkAsSkipped("skipped_album")
	manager.DB.AddNewAlbum("failed_album", testTime)
	manager.DB.MarkAsFailed("failed_album")
	manager.Close()

	// Run stats command while another command is running
	// First start a long-running command in the background
	cmdChan := make(chan error)
	go func() {
		_, err := runBinary(env.homeDir, "--data-dir", env.dataDir, "--flac-dir", env.albumsDir, "import")
		cmdChan <- err
	}()

	// Give the import command time to start and acquire the lock
	time.Sleep(100 * time.Millisecond)

	// Now run stats command - this should work even though import is running
	output, err := runBinary(env.homeDir, "--data-dir", env.dataDir, "--flac-dir", env.albumsDir, "stats")
	if err != nil {
		t.Errorf("Stats command failed while import was running: %v", err)
	}

	// Verify stats output
	expectedOutputs := []string{"imported: 1", "skipped: 1", "failed: 1"}
	for _, expected := range expectedOutputs {
		if !strings.Contains(output, expected) {
			t.Errorf("Expected output to contain %q, got %q", expected, output)
		}
	}

	// Wait for import command to finish
	if err := <-cmdChan; err != nil {
		t.Errorf("Import command failed: %v", err)
	}
}
