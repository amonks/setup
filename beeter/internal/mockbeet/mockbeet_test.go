package mockbeet

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"beeter/internal/fixtures"
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

func TestSetup(t *testing.T) {
	tmpDir, cleanup := setupTestDir(t)
	defer cleanup()

	setup(t, tmpDir)

	// Verify mock beet was created
	if _, err := os.Stat(tmpDir); err != nil {
		t.Errorf("Mock beet not created at %s: %v", tmpDir, err)
	}

	// Verify it's executable
	info, err := os.Stat(tmpDir)
	if err != nil {
		t.Fatalf("Failed to stat mock beet: %v", err)
	}
	if info.Mode()&0111 == 0 {
		t.Error("Mock beet is not executable")
	}
}

func TestMock(t *testing.T) {
	tmpDir, cleanup := setupTestDir(t)
	defer cleanup()

	setup(t, tmpDir)

	// Save original PATH
	origPath := os.Getenv("PATH")

	cleanup = Mock(t, tmpDir)
	defer cleanup()

	// Verify mock directory is in PATH
	newPath := os.Getenv("PATH")
	mockDir := filepath.Dir(tmpDir)
	if !strings.Contains(newPath, mockDir) {
		t.Errorf("Mock directory %s not found in PATH %s", mockDir, newPath)
	}

	cleanup()

	// Verify PATH was restored
	if path := os.Getenv("PATH"); path != origPath {
		t.Errorf("PATH not restored: got %s, want %s", path, origPath)
	}
}

func TestMockBeetBehavior(t *testing.T) {
	tmpDir, cleanup := setupTestDir(t)
	defer cleanup()

	// Create test albums directory
	albumsDir := filepath.Join(tmpDir, "albums")
	if err := os.MkdirAll(albumsDir, 0755); err != nil {
		t.Fatalf("Failed to create albums directory: %v", err)
	}

	// Create test albums
	albums := []string{
		"normal_album",
		"skip_this_album",
		"error_album",
	}
	fixtures.CreateTestAlbums(t, albumsDir, time.Now(), albums...)

	setup(t, tmpDir)

	tests := []struct {
		name       string
		args       []string
		wantLog    []string
		wantExit   int
		wantStderr string
	}{
		{
			name:     "no log file",
			args:     []string{"import", "album1"},
			wantExit: 1,
		},
		{
			name: "normal album",
			args: []string{"import", "--quiet", "-l", "test.log", filepath.Join(albumsDir, "normal_album")},
			wantLog: []string{
				"added " + filepath.Join(albumsDir, "normal_album"),
			},
			wantExit: 0,
		},
		{
			name: "skipped album",
			args: []string{"import", "--quiet", "-l", "test.log", filepath.Join(albumsDir, "skip_this_album")},
			wantLog: []string{
				"skip " + filepath.Join(albumsDir, "skip_this_album") + "; test skip condition",
			},
			wantExit: 0,
		},
		{
			name: "mixed batch with error",
			args: []string{
				"import", "--quiet", "-l", "test.log",
				filepath.Join(albumsDir, "normal_album"),
				filepath.Join(albumsDir, "skip_this_album"),
				filepath.Join(albumsDir, "error_album"),
			},
			wantLog: []string{
				"added " + filepath.Join(albumsDir, "normal_album"),
				"skip " + filepath.Join(albumsDir, "skip_this_album") + "; test skip condition",
			},
			wantExit: 1,
		},
		{
			name: "nonexistent album",
			args: []string{"import", "--quiet", "-l", "test.log", filepath.Join(albumsDir, "nonexistent")},
			wantLog: []string{
				"skip " + filepath.Join(albumsDir, "nonexistent") + "; does not exist",
			},
			wantExit: 0,
		},
		{
			name: "log file with spaces",
			args: []string{"import", "--quiet", "-l", "test log.log", filepath.Join(albumsDir, "normal_album")},
			wantLog: []string{
				"added " + filepath.Join(albumsDir, "normal_album"),
			},
			wantExit: 0,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			cleanup := Mock(t, tmpDir)
			defer cleanup()

			// Create a unique log file for this test
			logFile := filepath.Join(tmpDir, strings.ReplaceAll(tt.name, " ", "_")+".log")

			// Replace the log file path in args
			args := make([]string, len(tt.args))
			copy(args, tt.args)
			for i := range args {
				if args[i] == "test.log" || args[i] == "test log.log" {
					args[i] = logFile
				}
			}

			// Run mock beet
			cmd := exec.Command("beet", args...)
			output, err := cmd.CombinedOutput()

			// Check exit code
			exitCode := 0
			if err != nil {
				if exitErr, ok := err.(*exec.ExitError); ok {
					exitCode = exitErr.ExitCode()
				} else {
					t.Fatalf("Failed to run mock beet: %v", err)
				}
			}
			if exitCode != tt.wantExit {
				t.Errorf("Exit code = %d, want %d", exitCode, tt.wantExit)
			}

			// Check log file contents if expected
			if tt.wantLog != nil {
				logContent, err := os.ReadFile(logFile)
				if err != nil {
					t.Fatalf("Failed to read log file: %v", err)
				}

				gotLines := strings.Split(strings.TrimSpace(string(logContent)), "\n")
				if string(logContent) == "" {
					gotLines = nil
				}
				if len(gotLines) != len(tt.wantLog) {
					t.Errorf("Log lines = %v, want %v", gotLines, tt.wantLog)
				} else {
					for i, want := range tt.wantLog {
						if i >= len(gotLines) || gotLines[i] != want {
							t.Errorf("Log line %d = %q, want %q", i, gotLines[i], want)
						}
					}
				}
			}

			// Check stderr output if expected
			if tt.wantStderr != "" && !strings.Contains(string(output), tt.wantStderr) {
				t.Errorf("Stderr = %q, want to contain %q", string(output), tt.wantStderr)
			}
		})
	}
}
