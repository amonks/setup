package beet

import (
	"bytes"
	"context"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"beeter/internal/log"
)

// Manager handles beet import operations
type Manager struct {
	tempDir   string
	albumsDir string
	parser    *log.Parser
}

// New creates a new importer manager
func New(tempDir string, albumsDir string) (*Manager, error) {
	// Verify flac directory exists
	info, err := os.Stat(albumsDir)
	if err != nil {
		return nil, fmt.Errorf("failed to access flac directory: %w", err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("flac path is not a directory: %s", albumsDir)
	}

	// Create temp directory if it doesn't exist
	if err := os.MkdirAll(tempDir, 0700); err != nil {
		return nil, fmt.Errorf("failed to create temp directory: %w", err)
	}

	return &Manager{
		tempDir:   tempDir,
		albumsDir: albumsDir,
		parser:    log.New(albumsDir),
	}, nil
}

// ImportBatch imports a batch of albums in quiet mode
func (m *Manager) ImportBatch(ctx context.Context, albums []string) ([]string, error) {
	if len(albums) > 0 && filepath.IsAbs(albums[0]) {
		return nil, fmt.Errorf("albums must be relative paths")
	}

	if len(albums) == 0 {
		return nil, nil
	}

	// Create temporary log file
	logFile := filepath.Join(m.tempDir, "beet-import.log")
	if err := m.cleanupLogFile(logFile); err != nil {
		return nil, err
	}
	defer m.cleanupLogFile(logFile)

	// Run beet import
	absAlbums := make([]string, len(albums))
	for i, album := range albums {
		absAlbums[i] = filepath.Join(m.albumsDir, album)
	}
	args := []string{"import", "--quiet", "-l", logFile}
	args = append(args, absAlbums...)
	cmd := exec.CommandContext(ctx, "beet", args...)

	// Capture stderr
	var stderr bytes.Buffer
	var stdout bytes.Buffer
	cmd.Stdout = io.MultiWriter(os.Stdout, &stdout)
	cmd.Stderr = io.MultiWriter(os.Stderr, &stderr)

	var runErr error
	if err := cmd.Run(); err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return nil, fmt.Errorf("import operation timed out")
		}
		runErr = err
	}

	// Check for error lines in output regardless of run error
	output := stderr.String() + "\n" + stdout.String()
	hasErrorLine := containsErrorLine(output)

	if hasErrorLine {
		// Return ImportError if error lines found
		return nil, &ImportError{
			err:    fmt.Errorf("error detected in output: %v", runErr),
			failed: albums,
		}
	}

	if runErr != nil {
		// Return regular error if Run failed but no error lines
		return nil, fmt.Errorf("beet import failed: %w", runErr)
	}

	// Parse log file to find skipped albums
	skipped, err := m.parser.ParseSkippedAlbums(logFile)
	if err != nil {
		return nil, fmt.Errorf("failed to parse log file: %w", err)
	}

	return skipped, nil
}

// ImportBatchInteractively imports a batch of albums with interaction; `beet`
// will prompt the user for details about each album in the batch.
func (m *Manager) ImportBatchInteractively(ctx context.Context, albums []string) error {
	if len(albums) > 0 && filepath.IsAbs(albums[0]) {
		return fmt.Errorf("albums must be relative paths")
	}

	if len(albums) == 0 {
		return nil
	}

	// Create temporary log file
	logFile := filepath.Join(m.tempDir, "beet-import.log")
	if err := m.cleanupLogFile(logFile); err != nil {
		return err
	}
	defer m.cleanupLogFile(logFile)

	// Run beet import with interaction
	absAlbums := make([]string, len(albums))
	for i, album := range albums {
		absAlbums[i] = filepath.Join(m.albumsDir, album)
	}
	args := []string{"import", "-l", logFile}
	args = append(args, absAlbums...)
	cmd := exec.CommandContext(ctx, "beet", args...)

	// Capture stderr while still showing output to user
	var stderr bytes.Buffer
	var stdout bytes.Buffer
	cmd.Stdin = os.Stdin
	cmd.Stdout = io.MultiWriter(os.Stdout, &stdout)
	cmd.Stderr = io.MultiWriter(os.Stderr, &stderr)

	var runErr error
	if err := cmd.Run(); err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return fmt.Errorf("import operation timed out")
		}
		runErr = err
	}

	// Check for error lines in output regardless of run error
	output := stderr.String() + "\n" + stdout.String()
	hasErrorLine := containsErrorLine(output)

	if hasErrorLine {
		// Return ImportError if error lines found
		return &ImportError{
			err:    fmt.Errorf("error detected in output: %v", runErr),
			failed: albums,
		}
	}

	if runErr != nil {
		// Return regular error if Run failed but no error lines
		return fmt.Errorf("beet import failed: %w", runErr)
	}

	return nil
}

// cleanupLogFile removes an existing log file and ensures its parent directory exists
func (m *Manager) cleanupLogFile(logFile string) error {
	// Ensure parent directory exists
	if err := os.MkdirAll(filepath.Dir(logFile), 0700); err != nil {
		return fmt.Errorf("failed to create log file directory: %w", err)
	}

	// Remove existing log file
	if err := os.Remove(logFile); err != nil && !os.IsNotExist(err) {
		return fmt.Errorf("failed to remove old log file: %w", err)
	}

	return nil
}

// ImportError represents an import operation that failed
type ImportError struct {
	err    error
	failed []string
}

func (e *ImportError) Error() string {
	return fmt.Sprintf("import failed: %v", e.err)
}

// FailedAlbums returns the list of albums that failed to import
func (e *ImportError) FailedAlbums() []string {
	return e.failed
}

// containsErrorLine checks if the output contains any lines starting with "error"
func containsErrorLine(output string) bool {
	lines := strings.Split(output, "\n")
	for _, line := range lines {
		if strings.HasPrefix(strings.ToLower(strings.TrimSpace(line)), "error") {
			return true
		}
		if strings.HasPrefix(strings.ToLower(strings.TrimSpace(line)), "traceback") {
			return true
		}
	}
	return false
}

// Remove executes 'beet rm' with the given argument
func (m *Manager) Remove(ctx context.Context, query string) error {
	args := append([]string{"rm"}, strings.Fields(query)...)
	cmd := exec.CommandContext(ctx, "beet", args...)

	// Connect standard IO
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	if err := cmd.Run(); err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return fmt.Errorf("remove operation timed out")
		}
		return fmt.Errorf("beet remove failed: %w", err)
	}

	return nil
}
