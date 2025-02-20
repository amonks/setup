package log

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// Parser handles parsing of beet's log files
type Parser struct {
	albumsDir string // Base directory to strip from paths
}

// New creates a new log parser
func New(albumsDir string) *Parser {
	return &Parser{
		albumsDir: filepath.Clean(albumsDir),
	}
}

// ParseSkippedAlbums parses a log file to identify which albums from a batch were skipped
func (p *Parser) ParseSkippedAlbums(logFile string) ([]string, error) {
	file, err := os.Open(logFile)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, nil // No log file means no skips
		}
		return nil, fmt.Errorf("failed to open log file: %w", err)
	}
	defer file.Close()

	var skipped []string
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := scanner.Text()
		if !strings.HasPrefix(line, "skip ") {
			continue
		}

		// Extract album path from "skip /path/to/album; reason"
		path := strings.TrimPrefix(line, "skip ")
		if idx := strings.Index(path, ";"); idx >= 0 {
			path = path[:idx]
		}
		path = strings.TrimSpace(path)
		path = filepath.Clean(path)

		// Convert to relative path
		if !filepath.IsAbs(path) {
			panic("relative path???")
		}
		rel, err := filepath.Rel(p.albumsDir, path)
		if err != nil {
			panic(fmt.Errorf("failed to make path relative: %w", err))
		}

		skipped = append(skipped, rel)
	}

	if err := scanner.Err(); err != nil {
		return nil, fmt.Errorf("error reading log file: %w", err)
	}

	return skipped, nil
}
