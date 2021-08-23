package main

import (
	"fmt"

	// Tests CGO
	_ "github.com/mattn/go-sqlite3"
)

func main() {
	fmt.Println("hello world")
}
