package main

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestMain(m *testing.M) {
	code := m.Run()
	os.Exit(code)
}

func createTempDirs(t *testing.T) (string, string, func()) {
	t.Helper()
	
	sourceDir, err := os.MkdirTemp("", "rootsync-source-*")
	if err != nil {
		t.Fatalf("failed to create temp source dir: %v", err)
	}
	
	destDir, err := os.MkdirTemp("", "rootsync-dest-*")
	if err != nil {
		os.RemoveAll(sourceDir)
		t.Fatalf("failed to create temp dest dir: %v", err)
	}
	
	cleanup := func() {
		os.RemoveAll(sourceDir)
		os.RemoveAll(destDir)
	}
	
	return sourceDir, destDir, cleanup
}

func createTestFile(t *testing.T, path, content string) {
	t.Helper()
	
	if err := os.MkdirAll(filepath.Dir(path), 0755); err != nil {
		t.Fatalf("failed to create directory: %v", err)
	}
	
	if err := os.WriteFile(path, []byte(content), 0644); err != nil {
		t.Fatalf("failed to create test file: %v", err)
	}
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func readFile(t *testing.T, path string) string {
	t.Helper()
	
	content, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("failed to read file %s: %v", path, err)
	}
	return string(content)
}

func TestExpandGlobs(t *testing.T) {
	sourceDir, _, cleanup := createTempDirs(t)
	defer cleanup()
	
	createTestFile(t, filepath.Join(sourceDir, "file1.txt"), "content1")
	createTestFile(t, filepath.Join(sourceDir, "file2.txt"), "content2")
	createTestFile(t, filepath.Join(sourceDir, "test.go"), "package main")
	
	origWd, _ := os.Getwd()
	defer os.Chdir(origWd)
	os.Chdir(sourceDir)
	
	tests := []struct {
		name     string
		patterns []string
		want     int
		wantErr  bool
	}{
		{
			name:     "single file glob",
			patterns: []string{"*.txt"},
			want:     2,
			wantErr:  false,
		},
		{
			name:     "single file exact",
			patterns: []string{"test.go"},
			want:     1,
			wantErr:  false,
		},
		{
			name:     "multiple patterns",
			patterns: []string{"*.txt", "*.go"},
			want:     3,
			wantErr:  false,
		},
		{
			name:     "no matches",
			patterns: []string{"*.nonexistent"},
			want:     0,
			wantErr:  true,
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, err := expandGlobs(tt.patterns)
			if (err != nil) != tt.wantErr {
				t.Errorf("expandGlobs() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			if !tt.wantErr && len(got) != tt.want {
				t.Errorf("expandGlobs() = %v files, want %v", len(got), tt.want)
			}
		})
	}
}

func TestCopyFile(t *testing.T) {
	sourceDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	srcFile := filepath.Join(sourceDir, "test.txt")
	destFile := filepath.Join(destDir, "test.txt")
	content := "test content for copy"
	
	createTestFile(t, srcFile, content)
	
	err := copyFile(srcFile, destFile)
	if err != nil {
		t.Fatalf("copyFile() error = %v", err)
	}
	
	if !fileExists(destFile) {
		t.Error("destination file was not created")
	}
	
	gotContent := readFile(t, destFile)
	if gotContent != content {
		t.Errorf("file content = %q, want %q", gotContent, content)
	}
	
	srcInfo, _ := os.Stat(srcFile)
	destInfo, _ := os.Stat(destFile)
	if !srcInfo.ModTime().Equal(destInfo.ModTime()) {
		t.Error("modification times do not match")
	}
}

func TestAddFile(t *testing.T) {
	srcDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	sourceDir = srcDir
	destinationDir = destDir
	
	testFile := filepath.Join(srcDir, "test.txt")
	content := "test content"
	createTestFile(t, testFile, content)
	
	err := addFile(testFile)
	if err != nil {
		t.Fatalf("addFile() error = %v", err)
	}
	
	destFile := filepath.Join(destDir, "test.txt")
	if !fileExists(destFile) {
		t.Error("file was not added to destination")
	}
	
	gotContent := readFile(t, destFile)
	if gotContent != content {
		t.Errorf("file content = %q, want %q", gotContent, content)
	}
}

func TestAddFileAlreadyExists(t *testing.T) {
	srcDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	sourceDir = srcDir
	destinationDir = destDir
	
	testFile := filepath.Join(srcDir, "test.txt")
	destFile := filepath.Join(destDir, "test.txt")
	
	createTestFile(t, testFile, "source content")
	createTestFile(t, destFile, "dest content")
	
	err := addFile(testFile)
	if err == nil {
		t.Error("addFile() should fail when destination file exists")
	}
	
	if !strings.Contains(err.Error(), "destination file already exists") {
		t.Errorf("error message = %q, want to contain 'destination file already exists'", err.Error())
	}
}

func TestAddDirectory(t *testing.T) {
	srcDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	sourceDir = srcDir
	destinationDir = destDir
	
	testDir := filepath.Join(srcDir, "testdir")
	createTestFile(t, filepath.Join(testDir, "file1.txt"), "content1")
	createTestFile(t, filepath.Join(testDir, "subdir", "file2.txt"), "content2")
	
	err := addDirectory(testDir)
	if err != nil {
		t.Fatalf("addDirectory() error = %v", err)
	}
	
	if !fileExists(filepath.Join(destDir, "testdir", "file1.txt")) {
		t.Error("file1.txt was not added")
	}
	
	if !fileExists(filepath.Join(destDir, "testdir", "subdir", "file2.txt")) {
		t.Error("subdir/file2.txt was not added")
	}
}

func TestAdd(t *testing.T) {
	srcDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	sourceDir = srcDir
	destinationDir = destDir
	
	tests := []struct {
		name    string
		path    string
		setup   func()
		wantErr bool
		errMsg  string
	}{
		{
			name: "add file",
			path: filepath.Join(srcDir, "test.txt"),
			setup: func() {
				createTestFile(t, filepath.Join(srcDir, "test.txt"), "content")
			},
			wantErr: false,
		},
		{
			name: "add directory",
			path: filepath.Join(srcDir, "testdir"),
			setup: func() {
				createTestFile(t, filepath.Join(srcDir, "testdir", "file.txt"), "content")
			},
			wantErr: false,
		},
		{
			name:    "path outside source",
			path:    "/tmp/outside.txt",
			setup:   func() {},
			wantErr: true,
			errMsg:  "path must be within source directory",
		},
		{
			name:    "nonexistent path",
			path:    filepath.Join(srcDir, "nonexistent.txt"),
			setup:   func() {},
			wantErr: true,
			errMsg:  "failed to access path",
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tt.setup()
			
			err := add(tt.path)
			if (err != nil) != tt.wantErr {
				t.Errorf("add() error = %v, wantErr %v", err, tt.wantErr)
				return
			}
			
			if tt.wantErr && tt.errMsg != "" && !strings.Contains(err.Error(), tt.errMsg) {
				t.Errorf("error message = %q, want to contain %q", err.Error(), tt.errMsg)
			}
		})
	}
}

func TestRemove(t *testing.T) {
	srcDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	sourceDir = srcDir
	destinationDir = destDir
	
	testFile := filepath.Join(srcDir, "test.txt")
	createTestFile(t, testFile, "content")
	createTestFile(t, filepath.Join(destDir, "test.txt"), "content")
	
	err := remove(testFile)
	if err != nil {
		t.Fatalf("remove() error = %v", err)
	}
	
	if fileExists(filepath.Join(destDir, "test.txt")) {
		t.Error("file was not removed from destination")
	}
}

func TestRemoveDirectory(t *testing.T) {
	destDir, _, cleanup := createTempDirs(t)
	defer cleanup()
	
	testDir := filepath.Join(destDir, "testdir")
	createTestFile(t, filepath.Join(testDir, "file1.txt"), "content1")
	createTestFile(t, filepath.Join(testDir, "subdir", "file2.txt"), "content2")
	
	err := removeDirectory(testDir)
	if err != nil {
		t.Fatalf("removeDirectory() error = %v", err)
	}
	
	if fileExists(testDir) {
		t.Error("directory was not removed")
	}
}

func TestRemoveNonexistent(t *testing.T) {
	srcDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	sourceDir = srcDir
	destinationDir = destDir
	
	testFile := filepath.Join(srcDir, "nonexistent.txt")
	
	err := remove(testFile)
	if err == nil {
		t.Error("remove() should fail for nonexistent destination file")
	}
	
	if !strings.Contains(err.Error(), "path does not exist in destination directory") {
		t.Errorf("error message = %q, want to contain 'path does not exist in destination directory'", err.Error())
	}
}

func TestListDestination(t *testing.T) {
	_, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	destinationDir = destDir
	
	createTestFile(t, filepath.Join(destDir, "file1.txt"), "content1")
	createTestFile(t, filepath.Join(destDir, "dir1", "file2.txt"), "content2")
	
	var buf bytes.Buffer
	oldStdout := os.Stdout
	r, w, _ := os.Pipe()
	os.Stdout = w
	
	done := make(chan bool)
	go func() {
		io.Copy(&buf, r)
		done <- true
	}()
	
	err := listDestination()
	
	w.Close()
	<-done
	os.Stdout = oldStdout
	
	if err != nil {
		t.Fatalf("listDestination() error = %v", err)
	}
	
	output := buf.String()
	if !strings.Contains(output, "file1.txt") {
		t.Errorf("output should contain file1.txt, got: %q", output)
	}
	if !strings.Contains(output, "dir1") {
		t.Errorf("output should contain dir1, got: %q", output)
	}
}

func TestPrintTree(t *testing.T) {
	_, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	createTestFile(t, filepath.Join(destDir, "file1.txt"), "content1")
	createTestFile(t, filepath.Join(destDir, "dir1", "file2.txt"), "content2")
	createTestFile(t, filepath.Join(destDir, "dir1", "file3.txt"), "content3")
	
	var buf bytes.Buffer
	oldStdout := os.Stdout
	r, w, _ := os.Pipe()
	os.Stdout = w
	
	done := make(chan bool)
	go func() {
		io.Copy(&buf, r)
		done <- true
	}()
	
	err := printTree(destDir, "", true)
	
	w.Close()
	<-done
	os.Stdout = oldStdout
	
	if err != nil {
		t.Fatalf("printTree() error = %v", err)
	}
	
	output := buf.String()
	if !strings.Contains(output, "├── ") && !strings.Contains(output, "└── ") {
		t.Errorf("output should contain tree characters, got: %q", output)
	}
}

func TestAddPaths(t *testing.T) {
	srcDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	sourceDir = srcDir
	destinationDir = destDir
	
	createTestFile(t, filepath.Join(srcDir, "file1.txt"), "content1")
	createTestFile(t, filepath.Join(srcDir, "file2.txt"), "content2")
	
	origWd, _ := os.Getwd()
	defer os.Chdir(origWd)
	os.Chdir(srcDir)
	
	err := addPaths([]string{"*.txt"})
	if err != nil {
		t.Fatalf("addPaths() error = %v", err)
	}
	
	if !fileExists(filepath.Join(destDir, "file1.txt")) {
		t.Error("file1.txt was not added")
	}
	if !fileExists(filepath.Join(destDir, "file2.txt")) {
		t.Error("file2.txt was not added")
	}
}

func TestRemovePaths(t *testing.T) {
	srcDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	sourceDir = srcDir
	destinationDir = destDir
	
	createTestFile(t, filepath.Join(srcDir, "file1.txt"), "content1")
	createTestFile(t, filepath.Join(srcDir, "file2.txt"), "content2")
	createTestFile(t, filepath.Join(destDir, "file1.txt"), "content1")
	createTestFile(t, filepath.Join(destDir, "file2.txt"), "content2")
	
	origWd, _ := os.Getwd()
	defer os.Chdir(origWd)
	os.Chdir(srcDir)
	
	err := removePaths([]string{"*.txt"})
	if err != nil {
		t.Fatalf("removePaths() error = %v", err)
	}
	
	if fileExists(filepath.Join(destDir, "file1.txt")) {
		t.Error("file1.txt was not removed")
	}
	if fileExists(filepath.Join(destDir, "file2.txt")) {
		t.Error("file2.txt was not removed")
	}
}

func TestSyncDirs(t *testing.T) {
	srcDir, destDir, cleanup := createTempDirs(t)
	defer cleanup()
	
	sourceDir = srcDir
	destinationDir = destDir
	
	createTestFile(t, filepath.Join(srcDir, "source_newer.txt"), "source content")
	time.Sleep(10 * time.Millisecond)
	createTestFile(t, filepath.Join(destDir, "source_newer.txt"), "dest content")
	
	oldStdin := os.Stdin
	defer func() { os.Stdin = oldStdin }()
	
	r, w, _ := os.Pipe()
	os.Stdin = r
	
	go func() {
		defer w.Close()
		fmt.Fprintln(w, "n")
	}()
	
	var buf bytes.Buffer
	oldStdout := os.Stdout
	r2, w2, _ := os.Pipe()
	os.Stdout = w2
	
	go func() {
		io.Copy(&buf, r2)
	}()
	
	err := syncDirs()
	
	w2.Close()
	os.Stdout = oldStdout
	
	if err != nil {
		t.Fatalf("syncDirs() error = %v", err)
	}
	
	output := buf.String()
	if !strings.Contains(output, "Checking") {
		t.Error("output should contain sync information")
	}
}

func TestPromptConfirmation(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected bool
	}{
		{"yes", "y\n", true},
		{"yes full", "yes\n", true},
		{"no", "n\n", false},
		{"no full", "no\n", false},
		{"empty", "\n", false},
		{"invalid", "maybe\n", false},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			oldStdin := os.Stdin
			defer func() { os.Stdin = oldStdin }()
			
			r, w, _ := os.Pipe()
			os.Stdin = r
			
			go func() {
				defer w.Close()
				w.Write([]byte(tt.input))
			}()
			
			var buf bytes.Buffer
			oldStdout := os.Stdout
			r2, w2, _ := os.Pipe()
			os.Stdout = w2
			
			go func() {
				io.Copy(&buf, r2)
			}()
			
			result := promptConfirmation("Test message")
			
			w2.Close()
			os.Stdout = oldStdout
			
			if result != tt.expected {
				t.Errorf("promptConfirmation() = %v, want %v", result, tt.expected)
			}
		})
	}
}

func TestShowDiff(t *testing.T) {
	file1, err := os.CreateTemp("", "test1-*.txt")
	if err != nil {
		t.Fatalf("failed to create temp file: %v", err)
	}
	defer os.Remove(file1.Name())
	
	file2, err := os.CreateTemp("", "test2-*.txt")
	if err != nil {
		t.Fatalf("failed to create temp file: %v", err)
	}
	defer os.Remove(file2.Name())
	
	file1.WriteString("line1\nline2\n")
	file1.Close()
	
	file2.WriteString("line1\nline2 modified\n")
	file2.Close()
	
	err = showDiff(file1.Name(), file2.Name())
	if err != nil {
		t.Errorf("showDiff() error = %v", err)
	}
}