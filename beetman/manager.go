package beeter

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"beeter/internal/albums"
	"beeter/internal/beet"
	"beeter/internal/database"
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
	Beet     *beet.Manager
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
	beetManager, err := beet.New(filepath.Join(opts.DataDir, "tmp"), opts.AlbumsDir)
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
		Beet:     beetManager,
		Parser:   log.New(opts.AlbumsDir),
	}, nil
}

// NewReadOnly creates a new BeetImportManager instance in read-only mode
// This constructor does not acquire a lock and should only be used for read-only operations
func NewReadOnly(opts Options) (*BeetImportManager, error) {
	if err := ensureDirectoryExists(opts.DataDir); err != nil {
		return nil, fmt.Errorf("initialization failed: %w", err)
	}

	// Open database
	db, err := database.New(opts.DataDir)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	// Create albums manager
	albumsManager, err := albums.New(opts.AlbumsDir)
	if err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to create albums manager: %w", err)
	}

	return &BeetImportManager{
		DB:       db,
		DataDir:  opts.DataDir,
		Lock:     nil,
		IsLocked: false,
		Albums:   albumsManager,
		Beet:     nil,
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
	fmt.Printf("Setup: found %d albums\n", len(albums))

	// Parse previous log file to identify skipped albums
	var skippedMap map[string]bool
	if previousLog != "" {
		// Parse log file to find skipped albums
		skipped, err := m.Parser.ParseSkippedAlbums(previousLog)
		if err != nil {
			return fmt.Errorf("failed to parse previous log: %w", err)
		}
		fmt.Printf("Setup: found %d skipped albums\n", len(skipped))

		// Create map for quick lookup, converting back to relative paths
		skippedMap = make(map[string]bool, len(skipped))
		for _, album := range skipped {
			skippedMap[album] = true
		}
	}

	// Process each album
	for i, album := range albums {
		if i%100 == 0 {
			fmt.Printf("Setup: processing album %d of %d: %s\n", i, len(albums), album)
		}

		mtime, err := m.Albums.GetAlbumMtime(album)
		if err != nil {
			return fmt.Errorf("failed to get album mtime: %w", err)
		}

		if err := m.DB.AddNewAlbum(album, mtime); err != nil {
			return fmt.Errorf("failed to add new album: %w", err)
		}

		if skippedMap[album] {
			if err := m.DB.MarkAsSkipped(album); err != nil {
				return fmt.Errorf("failed to mark album as skipped: %w", err)
			}
		} else if mtime.After(cutoff) {
			if err := m.DB.MarkAsPending(album); err != nil {
				return fmt.Errorf("failed to mark album as pending: %w", err)
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
	fmt.Printf("Import: found %d new albums\n", len(newAlbums))

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
		fmt.Printf("Import: processing %d pending albums\n", len(pending))

		// Process batch
		batch := pending
		if len(batch) > batchSize {
			batch = batch[:batchSize]
		}

		fmt.Println("Importing batch")

		// Import batch
		skipped, err := m.Beet.ImportBatch(batch)
		if err != nil {
			// Check if this is an ImportError containing failed albums
			if importErr, ok := err.(*beet.ImportError); ok {
				fmt.Printf("Import: %d albums failed to import\n", len(importErr.FailedAlbums()))
				if err := m.DB.MarkAsFailed(importErr.FailedAlbums()...); err != nil {
					return fmt.Errorf("failed to mark albums as failed: %w", err)
				}
				continue // Continue with next batch
			}
			return fmt.Errorf("failed to import batch: %w", err)
		}
		fmt.Printf("Import: skipped %d albums from batch\n", len(skipped))

		// Update status
		imported := make([]string, 0, len(batch))
		skippedMap := make(map[string]bool)
		for _, album := range skipped {
			skippedMap[album] = true
			fmt.Println("skipped: ", album)
		}
		for _, album := range batch {
			if !skippedMap[album] {
				imported = append(imported, album)
				fmt.Println("imported: ", album)
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
		if err := m.Beet.ImportSkippedBatch(batch); err != nil {
			// Check if this is an ImportError containing failed albums
			if importErr, ok := err.(*beet.ImportError); ok {
				fmt.Printf("Import: %d albums failed to import\n", len(importErr.FailedAlbums()))
				if err := m.DB.MarkAsFailed(importErr.FailedAlbums()...); err != nil {
					return fmt.Errorf("failed to mark albums as failed: %w", err)
				}
				continue // Continue with next batch
			}
			return fmt.Errorf("failed to import skipped batch: %w", err)
		}

		// Mark as imported
		if err := m.DB.MarkAsImported(batch...); err != nil {
			return fmt.Errorf("failed to mark albums as imported: %w", err)
		}
	}

	return nil
}

// HandleErrors retries failed albums one by one
func (m *BeetImportManager) HandleErrors() error {
	// Get all failed albums
	failedAlbums, err := m.DB.GetFailedAlbums()
	if err != nil {
		return fmt.Errorf("failed to get failed albums: %w", err)
	}

	// Retry each failed album
	for _, album := range failedAlbums {
		fmt.Printf("Processing failed album: %s\n", album)

		// Prompt for removal query
		fmt.Print("Enter beet remove query (press Enter to skip removal): ")
		var query string
		if _, err := fmt.Scanln(&query); err != nil && err.Error() != "unexpected newline" {
			return fmt.Errorf("failed to read query: %w", err)
		}

		// If query provided, run removal
		if query != "" {
			if err := m.Beet.Remove(query); err != nil {
				return fmt.Errorf("failed to remove entries: %w", err)
			}
		}

		fmt.Printf("Retrying album: %s\n", album)

		// Attempt to import the album
		skipped, err := m.Beet.ImportBatch([]string{album})
		if err != nil {
			// Increment failure count if it fails again
			if err := m.DB.IncrementFailureCount(album); err != nil {
				return fmt.Errorf("failed to increment failure count: %w", err)
			}
			fmt.Printf("Album %s failed again\n", album)
			continue
		}

		// Update status based on import result
		if len(skipped) > 0 {
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

// Stats returns the number of albums in each state
func (m *BeetImportManager) Stats() (map[string]int, error) {
	return m.DB.GetAlbumStats()
}
