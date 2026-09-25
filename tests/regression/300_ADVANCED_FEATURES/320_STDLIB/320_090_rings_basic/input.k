// Test: std/rings — a named ring carries u64 elements; enqueue/dequeue
// address it by name, `ok`/`full` and `some`/`none` are ordinary arms.
import std/rings
import std/io

std/rings:new(ring, capacity: 16) { value: u64 }

std/rings:enqueue(ring, v: 42)
| ok |> std/rings:enqueue(ring, v: 100)
    | ok |> std/rings:dequeue(ring)
        | some v |> std/io:print.ln("First: {{ v:d }}")
        | none |> std/io:print.ln("ERROR: empty")
    | full |> std/io:print.ln("ERROR: full")
| full |> std/io:print.ln("ERROR: full")
