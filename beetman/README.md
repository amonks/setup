# Beet Import Manager

A Go program that manages the import of music albums into a beet library. It maintains a SQLite database to track album import status and provides both interactive and non-interactive modes for handling imports.

## Features

- Tracks album import status in a SQLite database
- Supports both interactive and non-interactive import modes
- Automatically discovers new albums
- Handles skipped albums that need manual intervention
- Ensures only one instance runs at a time

## Installation

1. Ensure you have Go installed
2. Clone this repository
3. Run `go build ./cmd/beet-import-manager`

## Usage

```
beet-import-manager <command>

Commands:
  setup         Initialize database and process existing albums
                Required flags:
                  --cutoff-time    Timestamp before which albums are considered processed
                  --previous-log   Path to existing beet import log file
  import       Discover and import new albums (skipping those requiring interaction)
  handle-skips Import previously skipped albums that need interaction
```

## Data Storage

The program stores its data in `~/.local/share/beet-import-manager/`:
- `db.sqlite`: SQLite database containing album import status
- `lock`: Lock file to prevent multiple instances from running

## Development

### Project Structure

```
.
├── cmd/
│   └── main.go               # Main application
├── internal/
│   ├── albums/              # Album directory management
│   ├── database/            # Database interface and implementation
│   ├── importer/            # Album import logic
│   └── log/                 # Log parsing utilities
└── README.md
```

### Building

```bash
go build ./cmd/beet-import-manager
```

### Testing

```bash
go test ./...
```

## License

MIT License 