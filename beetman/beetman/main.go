package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"

	"beeter"
)

// printUsage prints the application usage information
func printUsage() {
	fmt.Println("Usage: beet-import-manager [--data-dir=PATH] [--flac-dir=PATH] <command>")
	fmt.Println("\nCommands:")
	fmt.Println("  setup         Initialize database and process existing albums")
	fmt.Println("  import        Discover and import new albums (skipping those requiring interaction)")
	fmt.Println("  handle-skips  Import previously skipped albums that need interaction")
	fmt.Println("  handle-skip   Import previously skipped albums matching a search query")
	fmt.Println("  handle-errors Retry failed albums one by one")
	fmt.Println("  stats         Get album stats")
	fmt.Println("  retry-skips   Retry importing previously skipped albums without interaction")

	fmt.Println("\nFlags:")
	flag.PrintDefaults()
}

func run() error {
	// Override the default usage function
	flag.Usage = printUsage

	// Create a cancellable context that handles signals
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Set up signal handling
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		sig := <-sigChan
		fmt.Printf("\nReceived signal %v, shutting down...\n", sig)
		cancel()
	}()

	// Define global flags
	dataDir := flag.String("data-dir", "", "Path to the application data directory")
	albumsDir := flag.String("flac-dir", "", "Path to the directory containing FLAC albums")

	// Parse global flags
	flag.Parse()

	// Check if a command was provided
	args := flag.Args()
	if len(args) < 1 {
		printUsage()
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
		return manager.Import(ctx)

	case "retry-skips":
		return manager.RetrySkips(ctx)

	case "handle-skips":
		return manager.HandleSkips(ctx)

	case "handle-skip":
		if len(args) < 2 {
			return fmt.Errorf("handle-skip requires at least one search term")
		}
		return manager.HandleSkip(ctx, args[1:])

	case "handle-errors":
		return manager.HandleErrors(ctx)

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
