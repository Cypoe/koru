// PINS the C-lane refusal for char[N] columns — fixed-width text cells
// are outside the C lane's first fragment.
import std/io
import std/store

std/store:new(todos, capacity: 8) { done: i64, label: char[16] }

std/store:insert(todos) { done: 0, label: "first" }
| row r |> std/io:print.ln("inserted")
