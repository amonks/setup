package main

import (
	"flag"
	"fmt"
	"os"

	"beeter"
)

func run() error {
	// Define global flags
	dataDir := flag.String("data-dir", "", "Path to the application data directory")
	albumsDir := flag.String("flac-dir", "", "Path to the directory containing FLAC albums")

	// Parse global flags
	flag.Parse()

	// Check if a command was provided
	args := flag.Args()
	if len(args) < 1 {
		fmt.Println("Usage: beet-import-manager [--data-dir=PATH] [--flac-dir=PATH] <command>")
		fmt.Println("\nCommands:")
		fmt.Println("  setup         Initialize database and process existing albums")
		fmt.Println("  import        Discover and import new albums (skipping those requiring interaction)")
		fmt.Println("  handle-skips  Import previously skipped albums that need interaction")
		fmt.Println("  handle-errors Retry failed albums one by one")
		fmt.Println("  stats         Get album stats")
		return fmt.Errorf("no command provided")
	}

	// Get default options
	opts, err := beeter.DefaultOptions()
	if err != nil {
		return fmt.Errorf("failed to get default options: %w", err)
	}

	// Override with command-line flags if provided
	if *dataDir != "" {
		opts.DataDir = *dataDir
	}
	if *albumsDir != "" {
		opts.AlbumsDir = *albumsDir
	}

	// Create manager instance based on command
	var manager *beeter.BeetImportManager
	if args[0] == "stats" {
		manager, err = beeter.NewReadOnly(opts)
	} else {
		manager, err = beeter.New(opts)
	}
	if err != nil {
		return fmt.Errorf("failed to create manager: %w", err)
	}
	defer manager.Close()

	// Define setup command flags
	setupCmd := flag.NewFlagSet("setup", flag.ExitOnError)
	cutoffTime := setupCmd.String("cutoff-time", "", "Timestamp before which albums are considered processed")
	previousLog := setupCmd.String("previous-log", "", "Path to existing beet import log file")

	// Parse command
	switch args[0] {
	case "setup":
		setupCmd.Parse(args[1:])
		if *cutoffTime == "" || *previousLog == "" {
			setupCmd.PrintDefaults()
			return fmt.Errorf("missing required flags for setup command")
		}
		return manager.Setup(*cutoffTime, *previousLog)

	case "import":
		return manager.Import()

	case "handle-skips":
		return manager.HandleSkips()

	case "handle-errors":
		return manager.HandleErrors()

	case "stats":
		stats, err := manager.Stats()
		if err != nil {
			return fmt.Errorf("failed to get stats: %w", err)
		}
		fmt.Println("Album Stats:")
		for status, count := range stats {
			fmt.Printf("%s: %d\n", status, count)
		}
		return nil

	default:
		return fmt.Errorf("unknown command: %s", args[0])
	}
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
