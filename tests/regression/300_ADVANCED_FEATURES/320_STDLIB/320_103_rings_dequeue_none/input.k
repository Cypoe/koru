// std/rings — `dequeue | none` is the empty answer, not an error: a
// consumer that finds nothing fires none and decides for itself whether
// to wait, poll again, or move on.
import std/rings
import std/io

std/rings:new(q, capacity: 4) { value: u64 }

std/rings:dequeue(q)
| some v |> std/io:print.ln("ERROR: got {{ v:d }}")
| none |> std/io:print.ln("none on empty")
