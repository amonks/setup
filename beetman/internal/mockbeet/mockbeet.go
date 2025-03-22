package mockbeet

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"
)

// Mock sets up a mock beet in the given directory and returns a cleanup function
func Mock(t *testing.T, dir string) func() {
	// Save original PATH
	origPath := os.Getenv("PATH")

	setup(t, dir)

	// Add mock directory to PATH
	newPath := fmt.Sprintf("%s%c%s", dir, os.PathListSeparator, origPath)
	if err := os.Setenv("PATH", newPath); err != nil {
		t.Fatalf("Failed to set PATH: %v", err)
	}

	// Return cleanup function
	return func() {
		os.Setenv("PATH", origPath)
	}
}

// setup creates a mock beet executable for testing
func setup(t *testing.T, tmpDir string) {
	// Create mock beet script
	mockScript := `#!/usr/bin/env fish

# Parse arguments
set -l quiet 0
set -l log_file ""
set -l albums
set -l command ""

while test (count $argv) -gt 0
    switch $argv[1]
        case "import"
            set command "import"
            set -e argv[1]
        case "rm"
            set command "rm"
            set -e argv[1]
        case "--quiet"
            set quiet 1
            set -e argv[1]
        case "-l"
            set log_file $argv[2]
            set -e argv[1]
            set -e argv[1]
        case "*"
            if test "$command" = "rm"
                # For rm command, treat remaining args as query
                set query $argv[1]
                set -e argv[1]
            else
                # For import command, treat as album paths
                set -a albums $argv[1]
                set -e argv[1]
            end
    end
end

# Handle rm command
if test "$command" = "rm"
    # Mock successful removal
    exit 0
end

# Handle import command
if test "$command" = "import"
    # If no log file specified, error out
    if test -z "$log_file"
        echo "Error: no log file specified" >&2
        exit 1
    end

    # Create log file directory if it doesn't exist
    mkdir -p (dirname "$log_file")

    # Create or truncate log file
    echo -n > "$log_file"

    # Process each album
    set -l has_error 0
    for album in $albums
        # Skip non-existent albums
        if not test -d "$album"
            echo "skip $album; does not exist" >> "$log_file"
            continue
        end

        # Skip albums with "skip" in their name
        if string match -q "*skip*" "$album"
            echo "skip $album; test skip condition" >> "$log_file"
            continue
        end

        # Check for error albums
        if string match -q "*error*" "$album"
            set has_error 1
            continue
        end

        # Otherwise, mark as added
        echo "added $album" >> "$log_file"
    end

    # Exit with error if any album had "error" in its name
    if test "$has_error" = "1"
        exit 1
    end

    exit 0
end

# Unknown command
echo "Error: unknown command" >&2
exit 1`

	// Create mock beet executable
	mockPath := filepath.Join(tmpDir, "beet")
	if err := os.WriteFile(mockPath, []byte(mockScript), 0755); err != nil {
		t.Fatalf("Failed to create mock beet: %v", err)
	}
}
