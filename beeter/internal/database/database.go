package database

import (
	"database/sql"
	"fmt"
	"os"
	"path/filepath"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

// SQLiteDB implements the Database interface using SQLite
type SQLiteDB struct {
	db *sql.DB
}

const schema = `
CREATE TABLE IF NOT EXISTS albums (
    directory_name TEXT PRIMARY KEY,
    discovery_time TEXT,
    mtime         TEXT,
    import_time   TEXT NULL,
    status        TEXT
);

CREATE INDEX IF NOT EXISTS idx_mtime ON albums(mtime);
`

const timeFormat = "2006-01-02 15:04:05.999999999Z07:00"

// New creates a new SQLite database connection and ensures the schema is created
func New(dataDir string) (*SQLiteDB, error) {
	if err := os.MkdirAll(dataDir, 0700); err != nil {
		return nil, fmt.Errorf("failed to create database directory: %w", err)
	}

	dbPath := filepath.Join(dataDir, "db.sqlite")
	db, err := sql.Open("sqlite3", dbPath)
	if err != nil {
		return nil, fmt.Errorf("failed to open database: %w", err)
	}

	if err := db.Ping(); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to ping database: %w", err)
	}

	if _, err := db.Exec(schema); err != nil {
		db.Close()
		return nil, fmt.Errorf("failed to create schema: %w", err)
	}

	return &SQLiteDB{db: db}, nil
}

func (s *SQLiteDB) Close() error {
	return s.db.Close()
}

func (s *SQLiteDB) AddNewAlbum(dirName string, mtime time.Time) error {
	query := `
		INSERT INTO albums (directory_name, discovery_time, mtime, status)
		VALUES (?, ?, ?, 'pending')
		ON CONFLICT(directory_name) DO NOTHING
	`
	_, err := s.db.Exec(query, dirName, time.Now().UTC().Format(timeFormat), mtime.UTC().Format(timeFormat))
	if err != nil {
		return fmt.Errorf("failed to add new album: %w", err)
	}
	return nil
}

func (s *SQLiteDB) GetLatestMtime() (time.Time, error) {
	var timeStr string
	err := s.db.QueryRow("SELECT COALESCE(MAX(mtime), '1970-01-01 00:00:00.000000000Z') FROM albums").Scan(&timeStr)
	if err != nil {
		return time.Time{}, fmt.Errorf("failed to get latest mtime: %w", err)
	}

	t, err := time.Parse(timeFormat, timeStr)
	if err != nil {
		return time.Time{}, fmt.Errorf("failed to parse time string %q: %w", timeStr, err)
	}
	return t, nil
}

func (s *SQLiteDB) GetPendingAlbums() ([]string, error) {
	return s.getAlbumsByStatus("pending")
}

func (s *SQLiteDB) GetSkippedAlbums() ([]string, error) {
	return s.getAlbumsByStatus("skipped")
}

func (s *SQLiteDB) GetImportedAlbums() ([]string, error) {
	return s.getAlbumsByStatus("imported")
}

func (s *SQLiteDB) getAlbumsByStatus(status string) ([]string, error) {
	rows, err := s.db.Query("SELECT directory_name FROM albums WHERE status = ?", status)
	if err != nil {
		return nil, fmt.Errorf("failed to query albums: %w", err)
	}
	defer rows.Close()

	var albums []string
	for rows.Next() {
		var album string
		if err := rows.Scan(&album); err != nil {
			return nil, fmt.Errorf("failed to scan album: %w", err)
		}
		albums = append(albums, album)
	}
	return albums, rows.Err()
}

func (s *SQLiteDB) MarkAsImported(albums ...string) error {
	return s.updateAlbumStatus(albums, "imported")
}

func (s *SQLiteDB) MarkAsSkipped(albums ...string) error {
	return s.updateAlbumStatus(albums, "skipped")
}

func (s *SQLiteDB) MarkAsPending(albums ...string) error {
	return s.updateAlbumStatus(albums, "pending")
}

func (s *SQLiteDB) updateAlbumStatus(albums []string, status string) error {
	tx, err := s.db.Begin()
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback()

	query := `
		UPDATE albums 
		SET status = ?,
		    import_time = CASE WHEN ? = 'imported' THEN ? ELSE NULL END
		WHERE directory_name = ?
	`
	stmt, err := tx.Prepare(query)
	if err != nil {
		return fmt.Errorf("failed to prepare statement: %w", err)
	}
	defer stmt.Close()

	now := time.Now().UTC().Format(timeFormat)
	for _, album := range albums {
		if _, err := stmt.Exec(status, status, now, album); err != nil {
			return fmt.Errorf("failed to update album status: %w", err)
		}
	}

	if err := tx.Commit(); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}
	return nil
}
