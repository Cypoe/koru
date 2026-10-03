package main

import (
	"fmt"
	"os"
)

func main() {
	f, _ := os.Create("/tmp/bakeoff_go_dispose.txt")
	f.Close()
	f.Write([]byte("late write")) // error ignored — write is silently lost
	fmt.Println("done")
}
