package main

import (
	"bufio"
	"os"
)

func main() {
	// Create a scanner that splits on any type of newline
	scanner := bufio.NewScanner(os.Stdin)

	// Read lines
	for scanner.Scan() {
		line := scanner.Text()
		// log.Printf("'%s'", line)
		_, _ = os.Stdout.WriteString(line + "\n")
	}

	if err := scanner.Err(); err != nil {
		os.Stderr.WriteString("error reading input: " + err.Error() + "\n")
		os.Exit(1)
	}
}
