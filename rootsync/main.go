package main

import (
	"flag"
	"fmt"
	"io"
	"log"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

var (
	sourceDir      string
	destinationDir string
)

func init() {
	flag.StringVar(&sourceDir, "source", "", "source directory")
	flag.StringVar(&destinationDir, "destination", "", "destination directory")
}

func main() {
	flag.Parse()

	if sourceDir == "" || destinationDir == "" {
		fmt.Fprintln(os.Stderr, "both -source and -destination flags are required")
		flag.Usage()
		os.Exit(1)
	}

	var err error
	sourceDir, err = filepath.Abs(sourceDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "invalid source path: %v\n", err)
		os.Exit(1)
	}
	destinationDir, err = filepath.Abs(destinationDir)
	if err != nil {
		fmt.Fprintf(os.Stderr, "invalid destination path: %v\n", err)
		os.Exit(1)
	}

	if flag.NArg() < 1 {
		fmt.Fprintln(os.Stderr, "command required: add, sync, rm, or ls")
		flag.Usage()
		os.Exit(1)
	}

	switch cmd := flag.Arg(0); cmd {
	case "add":
		if flag.NArg() < 2 {
			fmt.Fprintln(os.Stderr, "usage: rootsync add path/to/file-or-dir [additional-paths...]")
			os.Exit(1)
		}
		if err := addPaths(flag.Args()[1:]); err != nil {
			fmt.Fprintf(os.Stderr, "add failed: %v\n", err)
			os.Exit(1)
		}
	case "sync":
		if err := syncDirs(); err != nil {
			fmt.Fprintf(os.Stderr, "sync failed: %v\n", err)
			os.Exit(1)
		}
	case "rm":
		if flag.NArg() < 2 {
			fmt.Fprintln(os.Stderr, "usage: rootsync rm path/to/file-or-dir [additional-paths...]")
			os.Exit(1)
		}
		if err := removePaths(flag.Args()[1:]); err != nil {
			fmt.Fprintf(os.Stderr, "remove failed: %v\n", err)
			os.Exit(1)
		}
	case "ls":
		if err := listDestination(); err != nil {
			fmt.Fprintf(os.Stderr, "list failed: %v\n", err)
			os.Exit(1)
		}
	default:
		fmt.Fprintf(os.Stderr, "unknown command: %s\n", cmd)
		os.Exit(1)
	}
}

func listDestination() error {
	fmt.Printf("%s\n", destinationDir)
	return printTree(destinationDir, "", true)
}

func printTree(path, prefix string, isLast bool) error {
	entries, err := os.ReadDir(path)
	if err != nil {
		return fmt.Errorf("failed to read directory: %w", err)
	}

	sort.Slice(entries, func(i, j int) bool {
		iIsDir := entries[i].IsDir()
		jIsDir := entries[j].IsDir()
		if iIsDir != jIsDir {
			return iIsDir
		}
		return entries[i].Name() < entries[j].Name()
	})

	for i, entry := range entries {
		isLastEntry := i == len(entries)-1
		connector := "├── "
		if isLastEntry {
			connector = "└── "
		}

		fmt.Printf("%s%s%s\n", prefix, connector, entry.Name())

		if entry.IsDir() {
			newPrefix := prefix + "│   "
			if isLastEntry {
				newPrefix = prefix + "    "
			}
			if err := printTree(filepath.Join(path, entry.Name()), newPrefix, isLastEntry); err != nil {
				return err
			}
		}
	}

	return nil
}

func expandGlobs(patterns []string) ([]string, error) {
	var paths []string
	for _, pattern := range patterns {
		matches, err := filepath.Glob(pattern)
		if err != nil {
			return nil, fmt.Errorf("invalid glob pattern %q: %w", pattern, err)
		}
		if len(matches) == 0 {
			return nil, fmt.Errorf("no matches found for pattern: %s", pattern)
		}
		paths = append(paths, matches...)
	}
	return paths, nil
}

func removePaths(patterns []string) error {
	paths, err := expandGlobs(patterns)
	if err != nil {
		return err
	}

	var firstErr error
	for _, path := range paths {
		if err := remove(path); err != nil {
			if firstErr == nil {
				firstErr = fmt.Errorf("failed to remove %s: %w", path, err)
			}
			fmt.Fprintf(os.Stderr, "warning: failed to remove %s: %v\n", path, err)
		}
	}
	return firstErr
}

func addPaths(patterns []string) error {
	paths, err := expandGlobs(patterns)
	if err != nil {
		return err
	}

	var firstErr error
	for _, path := range paths {
		if err := add(path); err != nil {
			if firstErr == nil {
				firstErr = fmt.Errorf("failed to add %s: %w", path, err)
			}
			fmt.Fprintf(os.Stderr, "warning: failed to add %s: %v\n", path, err)
		}
	}
	return firstErr
}

func remove(path string) error {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return fmt.Errorf("invalid path: %w", err)
	}

	if !strings.HasPrefix(absPath, sourceDir) {
		return fmt.Errorf("path must be within source directory %s", sourceDir)
	}

	relPath, err := filepath.Rel(sourceDir, absPath)
	if err != nil {
		return fmt.Errorf("failed to get relative path: %w", err)
	}

	destPath := filepath.Join(destinationDir, relPath)

	info, err := os.Stat(destPath)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("path does not exist in destination directory: %s", destPath)
		}
		return fmt.Errorf("failed to access destination path: %w", err)
	}

	if info.IsDir() {
		return removeDirectory(destPath)
	}

	if err := os.Remove(destPath); err != nil {
		return fmt.Errorf("failed to remove file: %w", err)
	}

	return nil
}

func removeDirectory(dirPath string) error {
	entries, err := os.ReadDir(dirPath)
	if err != nil {
		return fmt.Errorf("failed to read directory: %w", err)
	}

	for _, entry := range entries {
		path := filepath.Join(dirPath, entry.Name())
		if entry.IsDir() {
			if err := removeDirectory(path); err != nil {
				return err
			}
		} else {
			if err := os.Remove(path); err != nil {
				return fmt.Errorf("failed to remove file %s: %w", path, err)
			}
		}
	}

	if err := os.Remove(dirPath); err != nil {
		return fmt.Errorf("failed to remove directory %s: %w", dirPath, err)
	}

	return nil
}

func add(path string) error {
	absPath, err := filepath.Abs(path)
	if err != nil {
		return fmt.Errorf("invalid path: %w", err)
	}

	if !strings.HasPrefix(absPath, sourceDir) {
		return fmt.Errorf("path must be within source directory %s", sourceDir)
	}

	info, err := os.Stat(absPath)
	if err != nil {
		return fmt.Errorf("failed to access path: %w", err)
	}

	if info.IsDir() {
		return addDirectory(absPath)
	}
	return addFile(absPath)
}

func addDirectory(dirPath string) error {
	return filepath.Walk(dirPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		return addFile(path)
	})
}

func addFile(filePath string) error {
	relPath, err := filepath.Rel(sourceDir, filePath)
	if err != nil {
		return fmt.Errorf("failed to get relative path: %w", err)
	}

	destPath := filepath.Join(destinationDir, relPath)

	if _, err := os.Stat(destPath); !os.IsNotExist(err) {
		return fmt.Errorf("destination file already exists: %s", destPath)
	}

	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		return fmt.Errorf("failed to create destination directory: %w", err)
	}

	return copyFile(filePath, destPath)
}

func syncDirs() error {
	return filepath.Walk(destinationDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}

		relPath, err := filepath.Rel(destinationDir, path)
		if err != nil {
			return fmt.Errorf("failed to get relative path: %w", err)
		}

		sourcePath := filepath.Join(sourceDir, relPath)
		destPath := path

		fmt.Printf("Checking %s\n", relPath)

		sourceInfo, err := os.Stat(sourcePath)
		if os.IsNotExist(err) {
			fmt.Printf("  → copying to source (file missing in source)\n")
			// File doesn't exist in source, copy from destination to source
			if err := os.MkdirAll(filepath.Dir(sourcePath), 0755); err != nil {
				return fmt.Errorf("failed to create source directory: %w", err)
			}
			return copyFile(destPath, sourcePath)
		}
		if err != nil {
			return fmt.Errorf("failed to stat source file: %w", err)
		}

		destInfo := info
		if sourceInfo.ModTime().After(destInfo.ModTime()) {
			fmt.Printf("  → copying to destination (source is newer)\n")
			return copyFile(sourcePath, destPath)
		} else if destInfo.ModTime().After(sourceInfo.ModTime()) {
			fmt.Printf("  → copying to source (destination is newer)\n")
			return copyFile(destPath, sourcePath)
		}

		fmt.Printf("  → no action needed (files are in sync)\n")
		return nil
	})
}

func copyFile(src, dst string) error {
	sourceFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("failed to open source file: %w", err)
	}
	defer sourceFile.Close()

	destFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("failed to create destination file: %w", err)
	}
	defer func() {
		closeErr := destFile.Close()
		if err == nil {
			err = closeErr
		}
	}()

	if _, err := io.Copy(destFile, sourceFile); err != nil {
		return fmt.Errorf("failed to copy file: %w", err)
	}

	sourceInfo, err := os.Stat(src)
	if err != nil {
		return fmt.Errorf("failed to stat source file: %w", err)
	}

	err = os.Chtimes(dst, time.Now(), sourceInfo.ModTime())
	if err != nil {
		return fmt.Errorf("failed to set file times: %w", err)
	}

	return nil
}
