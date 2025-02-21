# Beet Import Manager Technical Design

## Overview
This document describes the design of a Go program that manages the import of music albums into a beet library. The program maintains a SQLite database to track album import status and provides both interactive and non-interactive modes for handling imports.

## Package Structure

The program is organized into the following packages:

### Root Package (beeter)
The root package provides the main coordination layer:
- `BeetImportManager` struct that ties all components together
- Configuration via `Options` struct for paths and settings
- Process locking to ensure single instance operation

### Internal Packages
- `internal/db`: Handles SQLite database operations
  - Schema management
  - Album status tracking
  - Database migrations

- `internal/importer`: Manages beet import operations
  - Running beet commands
  - Handling interactive vs non-interactive modes
  - Managing temporary log files

- `internal/log`: Handles parsing of beet's log files
  - Identifying skipped albums
  - Extracting paths and reasons

- `internal/albums`: Manages the album directory
  - Scanning for new albums
  - Tracking modification times
  - Path management

### Command Package
- `cmd`: Contains the CLI interface
  - Command-line argument parsing
  - Environment setup
  - Error reporting

## Core Components

### 1. Database Schema and Storage

The program stores its state in a SQLite database. The location of this database and other paths are configured via the Options struct:

```go
type Options struct {
    // DataDir is the path to the application data directory (default: ~/.local/share/beet-import-manager)
    DataDir string

    // AlbumsDir is the path to the directory containing FLAC albums
    AlbumsDir string
}
```

The database schema is:

```sql
CREATE TABLE albums (
    directory_name TEXT PRIMARY KEY,  -- The album's directory name within the flac folder
    discovery_time TIMESTAMP,         -- When our program first saw this album
    mtime         TIMESTAMP,          -- The album directory's mtime when discovered
    import_time   TIMESTAMP NULL,     -- When the album was successfully imported (NULL if not yet imported)
    status        TEXT,               -- One of: 'pending', 'imported', 'skipped'
);

CREATE INDEX idx_mtime ON albums(mtime);  -- For efficient new album detection
```

### 2. Album Discovery

The program identifies new albums by scanning the configured FLAC directory:
1. Query the database for the most recent `mtime` of any known album
2. Use `os.ReadDir` to get all entries in the flac directory
3. For each directory entry (ignoring non-directories):
   - Get the directory's mtime using `os.Stat`
   - If mtime is newer than latest known:
     * Record its name, current time (discovery_time), mtime, and status='pending'

### 3. Import Process

#### Import Mode
1. Query database for pending albums
2. Process in batches of 10:
   ```bash
   beet import --quiet -l /path/to/templog /path/to/album1 /path/to/album2 ...
   ```
3. After each batch:
   - If beet exits nonzero: exit program with error
   - Parse beet-import.log to identify skipped albums
   - Update database:
     * Skipped albums: status='skipped'
     * Non-skipped albums: status='imported', import_time=current_time
   - Truncate beet-import.log

Here's what the import logs look like; we only care about lines that start with `skip `, and we only care about the path up to the semicolon (if there is one). We might have to strip some parent directories off the path to get it to match the album directory names in the database.

```
import started Wed Feb 19 11:24:58 2025
duplicate-replace /usr/home/ajm/mnt/whatbox/files/flac/William Parker - Universal Tonality (2022) [web - flac]
import started Wed Feb 19 11:27:40 2025
skip /usr/home/ajm/mnt/whatbox/files/flac/Gush - 2015 - The March [FLAC] [CD KOR005]
skip /usr/home/ajm/mnt/whatbox/files/flac/Lisa Ullén - 2018 - Piano Works [FLAC] [WEB]/Disc 01; /usr/home/ajm/mnt/whatbox/files/flac/Lisa Ullén - 2018 - Piano Works [FLAC] [WEB]/Disc 02; /usr/home/ajm/mnt/whatbox/files/flac/Lisa Ullén - 2018 - Piano Works [FLAC] [WEB]/Disc 03
skip /usr/home/ajm/mnt/whatbox/files/flac/William Parker & In Order to Survive - Live-Shapeshifter (2019) FLAC WEB; /usr/home/ajm/mnt/whatbox/files/flac/William Parker & In Order to Survive - Live-Shapeshifter (2019) FLAC WEB/Disc 1; /usr/home/ajm/mnt/whatbox/files/flac/William Parker & In Order to Survive - Live-Shapeshifter (2019) FLAC WEB/Disc 2
skip /usr/home/ajm/mnt/whatbox/files/flac/Michael Pisaro - Transparent City (Volumes 3 and 4) [FLAC] (2007); /usr/home/ajm/mnt/whatbox/files/flac/Michael Pisaro - Transparent City (Volumes 3 and 4) [FLAC] (2007)/Disc 1; /usr/home/ajm/mnt/whatbox/files/flac/Michael Pisaro - Transparent City (Volumes 3 and 4) [FLAC] (2007)/Disc 2
skip /usr/home/ajm/mnt/whatbox/files/flac/Daunik Lazro & Joëlle Léandre - 2013 - Hasparren [FLAC] [NBCD 62]
import started Wed Feb 19 11:40:32 2025
skip /usr/home/ajm/mnt/whatbox/files/flac/Charles Gayle, Milford Graves, William Parker - WEBO (Live) (2024) [FLAC]
skip /usr/home/ajm/mnt/whatbox/files/flac/Ivo Perelman & Matthew Shipp - 2017 - Live in Brussels [FLAC] [WEB]/Disc 01; /usr/home/ajm/mnt/whatbox/files/flac/Ivo Perelman & Matthew Shipp - 2017 - Live in Brussels [FLAC] [WEB]/Disc 02
skip /usr/home/ajm/mnt/whatbox/files/flac/Akira Sakata, Johan Berthling, Paal Nilssen - Love - Semikujira (2016)
skip /usr/home/ajm/mnt/whatbox/files/flac/Keith Jarrett - The Survivor's Suite (1977) [CD-FLAC] [CD Issue (1994)]
```

Note: Log files are created in a temporary directory and cleaned up after each batch.

#### Handle-Skips Mode
1. Query database for albums where status='skipped'
2. Process in batches of 10:
   ```bash
   beet import -l beet-import.log /path/to/album1 /path/to/album2 ...
   ```
   Note: When running beet without --quiet, it requires access to stdin/stdout for user interaction
3. After each batch:
   - If beet exits nonzero: exit program with error
   - For successful imports: update all albums in batch to status='imported', import_time=current_time
   - Truncate beet-import.log

### 4. Log Parsing

The log parser should:
1. Scan for lines starting with "skip "
2. Extract the album directory path after "skip "
3. Ignore any content after semicolon (subdirectory information)
4. Match extracted paths against the batch being processed

### 5. Process Management

To ensure data consistency, only one instance of the program can run at a time. This is enforced using a lock file at `~/.local/share/beet-import-manager/lock`. If the lock file exists and is locked, the program exits immediately with an error.

### 6. Runtime Initialization

Before any command executes, the program ensures its required directories exist:
1. Creates `~/.local/share/beet-import-manager/` if it doesn't exist
2. Sets appropriate permissions (700) on the directory
3. Exits with error if directory creation or permission setting fails

### 7. Initial Setup

The program requires an initial setup to handle existing albums. This is done via the `setup` command:

```
beet-import-manager setup --cutoff-time=TIMESTAMP --previous-log=PATH
```

The setup process:
1. Creates the database and required directories if they don't exist
2. Scans the flac directory for all albums
3. For each album found:
   - If mtime < cutoff-time:
     * Mark as 'skipped' if it appears in previous-log
     * Mark as 'imported' if it doesn't
   - If mtime >= cutoff-time:
     * Mark as 'pending'

## Command Line Interface

```
Usage: beet-import-manager <command>

Commands:
  setup         Initialize database and process existing albums
                Required flags:
                  --cutoff-time    Timestamp before which albums are considered processed
                  --previous-log   Path to existing beet import log file
  import       Discover and import new albums (skipping those requiring interaction)
  handle-skips Import previously skipped albums that need interaction
```

## Error Handling

1. Database errors: exit with error message
2. Filesystem errors: exit with error message
3. Beet import failures: exit with error message
4. No retry logic for any errors

## Implementation Plan

### Phase 1: Foundation
1. Project setup
   - Create Go module
   - Add SQLite dependency
   - Create package structure (root, internal/*, cmd)
   - Write initial README

2. Process management (root package)
   - Implement lock file creation and management
   - Add lock file checking
   - Write lock acquisition/release logic
   - Add tests for concurrent access

3. Configuration (root package)
   - Design Options struct with paths
   - Add validation logic
   - Write configuration tests
   - Implement defaults

### Phase 2: Core Components
4. Log parsing (internal/log)
   - Write log file reading logic
   - Implement skip detection
   - Add path extraction and normalization
   - Write tests with sample log files

5. Album directory management (internal/albums)
   - Implement directory reading logic
   - Add mtime checking and tracking
   - Write tests with mock filesystem
   - Add error handling for filesystem operations

6. Database layer (internal/database)
   - Implement schema creation/migrations
   - Write Database interface implementation
   - Add unit tests for all database operations
   - Create test fixtures with sample data

7. Beet integration (internal/importer)
   - Implement command execution
   - Add quiet vs interactive mode handling
   - Write tests with mock beet command
   - Add error handling for beet failures

### Phase 3: Manager Core Operations
8. Setup Operation
   - Implement time parsing for cutoff time
   - Add log file parsing for previous imports
   - Write setup logic to process existing albums
   - Add tests with mock filesystem and beet

9. Import Operation
   - Implement new album discovery logic
   - Add batch processing with configurable size
   - Write import status tracking
   - Add tests with mock filesystem and beet

10. Handle-Skips Operation
   - Implement skipped album retrieval
   - Add interactive import logic
   - Write status update tracking
   - Add tests with mock filesystem and beet

### Phase 4: CLI Integration
11. Command-line interface
   - Implement flag parsing for each command
   - Add validation for required flags
   - Write usage documentation
   - Add integration tests

12. Error handling and logging
   - Implement structured error types
   - Add error recovery strategies
   - Write user-friendly error messages
   - Add logging for debugging

### Phase 5: Integration and Testing
13. End-to-end testing
   - Write integration test suite
   - Add test fixtures and helpers
   - Create test scenarios for common use cases
   - Add performance tests for large libraries

14. Documentation and examples
   - Write detailed API documentation
   - Add usage examples for each command
   - Create troubleshooting guide
   - Write development guide

## Manager API Design

The manager's core operations are decomposed into smaller methods that coordinate the internal packages:

### Setup Operation
The setup operation initializes the database with existing albums:
1. Parse the cutoff time from RFC3339 format
2. Get all albums from the flac directory
3. For each album:
   - If mtime is before cutoff:
     * Check if it was skipped in previous log
     * Mark as skipped or imported accordingly
   - If mtime is after cutoff:
     * Add as new album for processing

### Import Operation
The import operation discovers and imports new albums:
1. Get latest processed album mtime from database
2. Discover new albums with mtime after latest
3. Add new albums to database as pending
4. Process pending albums in batches:
   - Import batch in quiet mode
   - Track skipped albums
   - Update status in database

### Handle-Skips Operation
The handle-skips operation processes previously skipped albums:
1. Get all skipped albums from database
2. Process in batches:
   - Import batch with interaction enabled
   - Update status in database
   - Handle user input/output

Each operation uses the internal packages:
- `albums` for filesystem operations
- `database` for state tracking
- `importer` for beet integration
- `log` for parsing beet output
