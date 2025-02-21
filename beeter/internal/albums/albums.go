package albums

import (
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// Manager handles operations on the album directory
type Manager struct {
	albumsDir string
}

// New creates a new album manager
func New(albumsDir string) (*Manager, error) {
	// Verify the directory exists
	info, err := os.Stat(albumsDir)
	if err != nil {
		return nil, fmt.Errorf("failed to access flac directory: %w", err)
	}
	if !info.IsDir() {
		return nil, fmt.Errorf("flac path is not a directory: %s", albumsDir)
	}

	return &Manager{
		albumsDir: albumsDir,
	}, nil
}

// GetNewAlbums returns a list of albums that have been modified since the given time
func (m *Manager) GetNewAlbums(since time.Time) ([]string, error) {
	var albums []string

	entries, err := os.ReadDir(m.albumsDir)
	if err != nil {
		return nil, fmt.Errorf("failed to read directory: %w", err)
	}

	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		relPath := entry.Name()

		info, err := entry.Info()
		if err != nil {
			return nil, fmt.Errorf("failed to get file info: %w", err)
		}

		if info.ModTime().After(since) {
			albums = append(albums, relPath)
		}
	}

	return albums, nil
}

// GetAlbumPath returns the absolute path to the album directory
func (m *Manager) GetAlbumPath(name string) (string, error) {
	// Validate that the album name is relative
	if filepath.IsAbs(name) {
		return "", fmt.Errorf("album name must be relative: %s", name)
	}

	// Join the flac directory with the album name
	return filepath.Join(m.albumsDir, name), nil
}

// GetAlbumMtime returns the modification time of the album directory
func (m *Manager) GetAlbumMtime(name string) (time.Time, error) {
	// Get the album path
	path, err := m.GetAlbumPath(name)
	if err != nil {
		return time.Time{}, fmt.Errorf("failed to get album path: %w", err)
	}

	// Get the file info
	info, err := os.Stat(path)
	if err != nil {
		return time.Time{}, fmt.Errorf("failed to get file info: %w", err)
	}

	// Check if it's a directory
	if !info.IsDir() {
		return time.Time{}, fmt.Errorf("path is not a directory: %s", name)
	}

	return info.ModTime(), nil
}

// ValidateAlbumPath checks if the album path exists and is a directory
func (m *Manager) ValidateAlbumPath(name string) error {
	// Get the album path
	path, err := m.GetAlbumPath(name)
	if err != nil {
		return fmt.Errorf("failed to get album path: %w", err)
	}

	// Check if the path exists and is a directory
	info, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("album does not exist: %s", name)
		}
		return fmt.Errorf("failed to get file info: %w", err)
	}

	if !info.IsDir() {
		return fmt.Errorf("album is not a directory: %s", name)
	}

	return nil
}

// AlbumsDir returns the path to the flac directory
func (m *Manager) AlbumsDir() string {
	return m.albumsDir
}
