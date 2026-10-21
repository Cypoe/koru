// PINS the C-lane refusal for std/indexes columns — the key-index
// substrate is outside the C lane's first fragment.
import std/io
import std/store
import std/indexes

std/store:new(players, capacity: 8) { key: i64, val: i64 }
std/indexes:store(players, key)

std/store:insert(players) { key: 10, val: 100 }
| row a |> std/io:print.ln("indexed")
