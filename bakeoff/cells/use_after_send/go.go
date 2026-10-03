package main

import "fmt"

type Src struct{ id int64 }

func main() {
	ch := make(chan *Src, 1)
	s := &Src{id: 1}
	ch <- s
	fmt.Println("poisoned read", s.id)
}
