package main

import (
	"fmt"

	// Tests CGO
	_ "github.com/mattn/go-sqlite3"
)

var (
	GitHash, Version, Time string
)

func main() {
	fmt.Println("hello world")
}
