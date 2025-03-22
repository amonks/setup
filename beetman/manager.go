package beeter

import (
	"bufio"
	"context"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"

	"beeter/internal/albums"
	"beeter/internal/beet"
	"beeter/internal/database"
	"beeter/internal/log"
)

const permissions = 0700
const batchSize = 10

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
func (m *BeetImportManager) Import(ctx context.Context) error {
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
	fmt.Printf("Import: found %d new albums since %s\n", len(newAlbums), latestMtime)

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

	// Process all pending albums
	return m.processPendingAlbums(ctx, "Import")
}

// RetrySkips attempts to import previously skipped albums automatically
func (m *BeetImportManager) RetrySkips(ctx context.Context) error {
	// Get all skipped albums
	skipped, err := m.DB.GetSkippedAlbums()
	if err != nil {
		return fmt.Errorf("RetrySkips failed: failed to get skipped albums: %w", err)
	}
	if len(skipped) == 0 {
		fmt.Println("RetrySkips: no skipped albums found")
		return nil
	}
	fmt.Printf("RetrySkips: found %d skipped albums\n", len(skipped))

	// Process albums in batches with non-interactive import
	return m.processAlbumBatches(ctx, skipped, m.importBatchNonInteractive, "RetrySkips")
}

// HandleSkips imports previously skipped albums that need interaction
func (m *BeetImportManager) HandleSkips(ctx context.Context) error {
	// Get all skipped albums
	skipped, err := m.DB.GetSkippedAlbums()
	if err != nil {
		return fmt.Errorf("failed to get skipped albums: %w", err)
	}

	// Process albums in batches with interactive import
	return m.processAlbumBatches(ctx, skipped, m.importBatchInteractive, "HandleSkips")
}

// HandleErrors retries failed albums one by one
func (m *BeetImportManager) HandleErrors(ctx context.Context) error {
	// Get all failed albums
	failedAlbums, err := m.DB.GetFailedAlbums()
	if err != nil {
		return fmt.Errorf("failed to get failed albums: %w", err)
	}

	// Retry each failed album
	for _, album := range failedAlbums {
		query := "-"
		for strings.TrimSpace(query) != "" {
			if err := ctx.Err(); err != nil {
				return fmt.Errorf("error handling cancelled: %w", err)
			}

			fmt.Printf("Processing failed album: %s\n", album)

			// Prompt for removal query
			fmt.Print("Enter beet remove query (press Enter to skip removal): ")
			query, err = bufio.NewReader(os.Stdin).ReadString('\n')
			if err != nil {
				return fmt.Errorf("failed to read query: %w", err)
			}

			// If query provided, run removal
			if strings.TrimSpace(query) != "" {
				fmt.Printf("Query: %s\n", query)
				if err := m.Beet.Remove(ctx, query); err != nil {
					fmt.Printf("failed to remove entries: %s\n", err)
				}
			}
		}

		fmt.Printf("Retrying album: %s\n", album)

		// Attempt to import the album
		skipped, err := m.Beet.ImportBatch(ctx, []string{album})
		if err != nil {
			// Increment failure count if it fails again
			if err := m.DB.IncrementFailureCount(album); err != nil {
				return fmt.Errorf("failed to increment failure count: %w", err)
			}
			// Update timestamp for albums that remain failed
			if err := m.DB.UpdateStatusTimestamp(album); err != nil {
				return fmt.Errorf("failed to update status timestamp for failed album: %w", err)
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

// HandleSkip imports previously skipped albums that match a search query
func (m *BeetImportManager) HandleSkip(ctx context.Context, queryTerms []string) error {
	// Return an error if no search terms provided
	if len(queryTerms) == 0 {
		return fmt.Errorf("at least one search term is required")
	}

	// Get all skipped albums
	skipped, err := m.DB.GetSkippedAlbums()
	if err != nil {
		return fmt.Errorf("failed to get skipped albums: %w", err)
	}

	if len(skipped) == 0 {
		fmt.Println("HandleSkip: no skipped albums found")
		return nil
	}

	// Filter albums that match the query terms
	var matches []string
	for _, album := range skipped {
		if matchesQuery(album, queryTerms) {
			matches = append(matches, album)
		}
	}

	if len(matches) == 0 {
		fmt.Printf("HandleSkip: no skipped albums match the query: %s\n", strings.Join(queryTerms, " "))
		return nil
	}

	fmt.Printf("HandleSkip: found %d matching skipped albums\n", len(matches))

	// Process matching albums with interactive import
	return m.processAlbumBatches(ctx, matches, m.importBatchInteractive, "HandleSkip")
}

// matchesQuery checks if a directory name matches all of the query terms
func matchesQuery(dirName string, queryTerms []string) bool {
	// Case-insensitive comparison
	dirName = strings.ToLower(dirName)

	// Check if all query terms are found in the directory name
	for _, term := range queryTerms {
		if !strings.Contains(dirName, strings.ToLower(term)) {
			return false
		}
	}

	return true
}

// ImportFunction is a function type for batch importing albums
type ImportFunction func(ctx context.Context, batch []string) ([]string, error)

// processAlbumBatches processes albums in batches using the provided import function
func (m *BeetImportManager) processAlbumBatches(
	ctx context.Context,
	albums []string,
	importFn ImportFunction,
	operation string,
) error {
	for i := 0; i < len(albums); i += batchSize {
		if err := ctx.Err(); err != nil {
			return fmt.Errorf("%s cancelled: %w", operation, err)
		}

		end := i + batchSize
		if end > len(albums) {
			end = len(albums)
		}
		batch := albums[i:end]

		fmt.Printf("%s: processing batch of %d albums\n", operation, len(batch))

		skipped, err := importFn(ctx, batch)
		if err != nil {
			if err := m.handleImportError(err, batch, operation); err != nil {
				return err
			}
			continue // Continue with next batch after handling error
		}

		if err := m.updateAlbumStatuses(batch, skipped, operation); err != nil {
			return err
		}
	}
	return nil
}

// processPendingAlbums processes all pending albums in batches
func (m *BeetImportManager) processPendingAlbums(ctx context.Context, operation string) error {
	for {
		if err := ctx.Err(); err != nil {
			return fmt.Errorf("%s cancelled: %w", operation, err)
		}

		pending, err := m.DB.GetPendingAlbums()
		if err != nil {
			return fmt.Errorf("%s failed: failed to get pending albums: %w", operation, err)
		}
		if len(pending) == 0 {
			break
		}
		fmt.Printf("%s: processing %d pending albums\n", operation, len(pending))

		// Process batch
		batch := pending
		if len(batch) > batchSize {
			batch = batch[:batchSize]
		}

		fmt.Printf("%s: importing batch\n", operation)

		skipped, err := m.importBatchNonInteractive(ctx, batch)
		if err != nil {
			if err := m.handleImportError(err, batch, operation); err != nil {
				return err
			}
			continue // Continue with next batch after handling error
		}

		if err := m.updateAlbumStatuses(batch, skipped, operation); err != nil {
			return err
		}
	}
	return nil
}

// importBatchNonInteractive imports a batch of albums without user interaction
func (m *BeetImportManager) importBatchNonInteractive(ctx context.Context, batch []string) ([]string, error) {
	return m.Beet.ImportBatch(ctx, batch)
}

// importBatchInteractive imports a batch of albums with user interaction
func (m *BeetImportManager) importBatchInteractive(ctx context.Context, batch []string) ([]string, error) {
	// ImportBatchInteractively doesn't return skipped albums, so we return an empty slice
	if err := m.Beet.ImportBatchInteractively(ctx, batch); err != nil {
		return nil, err
	}
	return []string{}, nil
}

// handleImportError handles errors from the import process
func (m *BeetImportManager) handleImportError(err error, batch []string, operation string) error {
	// Check if this is an ImportError containing failed albums
	if importErr, ok := err.(*beet.ImportError); ok {
		failedAlbums := importErr.FailedAlbums()
		fmt.Printf("%s: %d albums failed to import\n", operation, len(failedAlbums))

		// For Import, we want to mark the albums as failed, otherwise retain as skipped.
		if operation == "Import" {
			if markErr := m.DB.MarkAsFailed(failedAlbums...); markErr != nil {
				return fmt.Errorf("%s failed: failed to mark albums as failed: %w", operation, markErr)
			}
			return nil
		}

		if markErr := m.DB.UpdateStatusTimestamp(failedAlbums...); markErr != nil {
			return fmt.Errorf("%s failed: failed to update status timestamps for skipped albums: %w", operation, markErr)
		}
		return nil
	}

	// For context cancellation or other errors, handle based on operation
	// For Import, mark as failed, otherwise retain as skipped.
	if operation == "Import" {
		if markErr := m.DB.MarkAsFailed(batch...); markErr != nil {
			return fmt.Errorf("%s failed: failed to mark batch as failed after import error: %w (original error: %v)",
				operation, markErr, err)
		}
		fmt.Printf("%s: import error occurred but continuing: %v\n", operation, err)
		return nil
	}

	if markErr := m.DB.UpdateStatusTimestamp(batch...); markErr != nil {
		return fmt.Errorf("%s failed: failed to update status timestamps after import error: %w (original error: %v)",
			operation, markErr, err)
	}
	fmt.Printf("%s: import error occurred but continuing: %v\n", operation, err)
	return nil
}

// updateAlbumStatuses updates album statuses based on import results
func (m *BeetImportManager) updateAlbumStatuses(batch []string, skipped []string, operation string) error {
	// Create a map to track which original paths are skipped
	skippedMap := make(map[string]bool)
	for _, skippedPath := range skipped {
		skippedMap[skippedPath] = true
		fmt.Printf("%s: skipped: %s\n", operation, skippedPath)
	}

	// Identify albums that were successfully imported
	imported := make([]string, 0, len(batch))
	stillSkipped := make([]string, 0, len(batch))
	for _, path := range batch {
		if !skippedMap[path] {
			imported = append(imported, path)
			fmt.Printf("%s: imported: %s\n", operation, path)
		} else {
			stillSkipped = append(stillSkipped, path)
		}
	}

	fmt.Printf("%s: imported %d albums, %d still skipped\n", operation, len(imported), len(stillSkipped))

	// Update status in database
	if len(imported) > 0 {
		if err := m.DB.MarkAsImported(imported...); err != nil {
			return fmt.Errorf("%s failed: failed to mark albums as imported: %w", operation, err)
		}
	}

	// Update skipped albums
	if len(stillSkipped) > 0 {
		if err := m.DB.MarkAsSkipped(stillSkipped...); err != nil {
			return fmt.Errorf("%s failed: failed to mark albums as skipped: %w", operation, err)
		}

		// For RetrySkips, we also update the timestamp
		if operation == "RetrySkips" {
			if err := m.DB.UpdateStatusTimestamp(stillSkipped...); err != nil {
				return fmt.Errorf("%s failed: failed to update status timestamps for skipped albums: %w", operation, err)
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
