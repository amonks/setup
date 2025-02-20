package beeter

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"beeter/internal/albums"
	"beeter/internal/database"
	"beeter/internal/importer"
	"beeter/internal/log"
)

const permissions = 0700

// Options configures the BeetImportManager
type Options struct {
	// DataDir is the path to the application data directory (default: ~/.local/share/beet-import-manager)
	DataDir string

	// AlbumsDir is the path to the directory containing FLAC albums
	AlbumsDir string
}

// DefaultOptionsFunc returns the default configuration
type DefaultOptionsFunc func() (Options, error)

// DefaultOptions returns the default configuration
var DefaultOptions DefaultOptionsFunc = func() (Options, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return Options{}, fmt.Errorf("failed to get home directory: %w", err)
	}

	return Options{
		DataDir:   filepath.Join(homeDir, ".local/share/beet-import-manager"),
		AlbumsDir: filepath.Join(homeDir, "mnt/whatbox/files/flac"),
	}, nil
}

// BeetImportManager coordinates the import of music albums into a beet library
type BeetImportManager struct {
	DB       *database.SQLiteDB
	DataDir  string
	Lock     *LockManager
	IsLocked bool
	Albums   *albums.Manager
	Importer *importer.Manager
	Parser   *log.Parser
}

// New creates a new BeetImportManager instance
func New(opts Options) (*BeetImportManager, error) {
	if err := ensureDirectoryExists(opts.DataDir); err != nil {
		return nil, fmt.Errorf("initialization failed: %w", err)
	}

	// Create lock manager
	lock := NewLockManager(opts.DataDir)
	if err := lock.AcquireLock(); err != nil {
		return nil, fmt.Errorf("failed to acquire lock: %w", err)
	}

	// Open database
	db, err := database.New(opts.DataDir)
	if err != nil {
		lock.ReleaseLock()
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Create albums manager
	albumsManager, err := albums.New(opts.AlbumsDir)
	if err != nil {
		db.Close()
		lock.ReleaseLock()
		return nil, fmt.Errorf("failed to create albums manager: %w", err)
	}

	// Create importer manager
	importManager, err := importer.New(filepath.Join(opts.DataDir, "tmp"), opts.AlbumsDir)
	if err != nil {
		db.Close()
		lock.ReleaseLock()
		return nil, fmt.Errorf("failed to create importer manager: %w", err)
	}

	return &BeetImportManager{
		DB:       db,
		DataDir:  opts.DataDir,
		Lock:     lock,
		IsLocked: true,
		Albums:   albumsManager,
		Importer: importManager,
		Parser:   log.New(opts.AlbumsDir),
	}, nil
}

// Close releases resources held by the manager
func (m *BeetImportManager) Close() error {
	var errs []error

	if m.DB != nil {
		if err := m.DB.Close(); err != nil {
			errs = append(errs, fmt.Errorf("failed to close database: %w", err))
		}
	}

	if m.IsLocked {
		if err := m.Lock.ReleaseLock(); err != nil {
			errs = append(errs, fmt.Errorf("failed to release lock: %w", err))
		}
		m.IsLocked = false
	}

	if len(errs) > 0 {
		return fmt.Errorf("errors during close: %v", errs)
	}
	return nil
}

// Setup initializes the database and processes existing albums
func (m *BeetImportManager) Setup(cutoffTime string, previousLog string) error {
	// Parse cutoff time
	cutoff, err := time.Parse(time.RFC3339, cutoffTime)
	if err != nil {
		return fmt.Errorf("invalid cutoff time: %w", err)
	}

	// Verify previous log exists if specified
	if previousLog != "" {
		if _, err := os.Stat(previousLog); err != nil {
			return fmt.Errorf("failed to access previous log: %w", err)
		}
	}

	// Get all albums from flac directory
	albums, err := m.Albums.GetNewAlbums(time.Time{}) // Zero time to get all albums
	if err != nil {
		return fmt.Errorf("failed to get albums: %w", err)
	}
	fmt.Printf("Setup: found albums: %v\n", albums)

	// Parse previous log file to identify skipped albums
	var skippedMap map[string]bool
	if previousLog != "" {
		// Parse log file to find skipped albums
		skipped, err := m.Parser.ParseSkippedAlbums(previousLog)
		if err != nil {
			return fmt.Errorf("failed to parse previous log: %w", err)
		}
		fmt.Printf("Setup: found skipped albums: %v\n", skipped)

		// Create map for quick lookup, converting back to relative paths
		skippedMap = make(map[string]bool, len(skipped))
		for _, album := range skipped {
			skippedMap[album] = true
		}
	}

	// Process each album
	for _, album := range albums {
		fmt.Printf("Setup: processing album: %s\n", album)
		mtime, err := m.Albums.GetAlbumMtime(album)
		if err != nil {
			return fmt.Errorf("failed to get album mtime: %w", err)
		}

		if err := m.DB.AddNewAlbum(album, mtime); err != nil {
			return fmt.Errorf("failed to add new album: %w", err)
		}
		if mtime.After(cutoff) {
			if err := m.DB.MarkAsPending(album); err != nil {
				return fmt.Errorf("failed to mark album as pending: %w", err)
			}
		} else if skippedMap[album] {
			if err := m.DB.MarkAsSkipped(album); err != nil {
				return fmt.Errorf("failed to mark album as skipped: %w", err)
			}
		} else {
			if err := m.DB.MarkAsImported(album); err != nil {
				return fmt.Errorf("failed to mark album as imported: %w", err)
			}
		}
	}

	return nil
}

// Import discovers and imports new albums
func (m *BeetImportManager) Import() error {
	// Get latest processed album mtime
	latestMtime, err := m.DB.GetLatestMtime()
	if err != nil {
		return fmt.Errorf("failed to get latest mtime: %w", err)
	}

	// Get new albums
	newAlbums, err := m.Albums.GetNewAlbums(latestMtime)
	if err != nil {
		return fmt.Errorf("failed to get new albums: %w", err)
	}
	fmt.Printf("Import: found new albums: %v\n", newAlbums)

	// Add new albums to database
	for _, album := range newAlbums {
		fmt.Printf("Import: processing new album: %s\n", album)
		mtime, err := m.Albums.GetAlbumMtime(album)
		if err != nil {
			return fmt.Errorf("failed to get album mtime: %w", err)
		}
		if err := m.DB.AddNewAlbum(album, mtime); err != nil {
			return fmt.Errorf("failed to add new album: %w", err)
		}
	}

	// Process pending albums in batches
	const batchSize = 10
	for {
		pending, err := m.DB.GetPendingAlbums()
		if err != nil {
			return fmt.Errorf("failed to get pending albums: %w", err)
		}
		if len(pending) == 0 {
			break
		}
		fmt.Printf("Import: processing pending albums: %v\n", pending)

		// Process batch
		batch := pending
		if len(batch) > batchSize {
			batch = batch[:batchSize]
		}

		// Import batch
		skipped, err := m.Importer.ImportBatch(batch)
		if err != nil {
			return fmt.Errorf("failed to import batch: %w", err)
		}
		fmt.Printf("Import: skipped albums from batch: %v\n", skipped)

		// Update status
		imported := make([]string, 0, len(batch))
		skippedMap := make(map[string]bool)
		for _, album := range skipped {
			skippedMap[album] = true
		}
		for _, album := range batch {
			if !skippedMap[album] {
				imported = append(imported, album)
			}
		}

		if len(skipped) > 0 {
			if err := m.DB.MarkAsSkipped(skipped...); err != nil {
				return fmt.Errorf("failed to mark albums as skipped: %w", err)
			}
		}
		if len(imported) > 0 {
			if err := m.DB.MarkAsImported(imported...); err != nil {
				return fmt.Errorf("failed to mark albums as imported: %w", err)
			}
		}
	}

	return nil
}

// HandleSkips imports previously skipped albums that need interaction
func (m *BeetImportManager) HandleSkips() error {
	// Get all skipped albums
	skipped, err := m.DB.GetSkippedAlbums()
	if err != nil {
		return fmt.Errorf("failed to get skipped albums: %w", err)
	}

	// Process in batches
	const batchSize = 10
	for i := 0; i < len(skipped); i += batchSize {
		end := i + batchSize
		if end > len(skipped) {
			end = len(skipped)
		}
		batch := skipped[i:end]

		// Import batch with interaction
		if err := m.Importer.ImportSkippedBatch(batch); err != nil {
			return fmt.Errorf("failed to import skipped batch: %w", err)
		}

		// Mark as imported
		if err := m.DB.MarkAsImported(batch...); err != nil {
			return fmt.Errorf("failed to mark albums as imported: %w", err)
		}
	}

	return nil
}

// ensureDirectoryExists creates the data directory if it doesn't exist
func ensureDirectoryExists(dir string) error {
	if err := os.MkdirAll(dir, permissions); err != nil {
		return fmt.Errorf("failed to create data directory: %w", err)
	}

	// Ensure correct permissions even if directory already existed
	if err := os.Chmod(dir, permissions); err != nil {
		return fmt.Errorf("failed to set directory permissions: %w", err)
	}

	return nil
}
