// Pins the enclosing-arm claim: an unhandled branch at depth N resolves
// outward to the nearest enclosing continuation that names it — when the
// shapes are compatible (void `full` claims void `full`, no binding). The
// single outer `| full` must satisfy the `full` produced by BOTH nested
// enqueues; capacity 2 makes the THIRD enqueue fire `full` at runtime.
// OWED: today coverage is sibling-level only (KORU022); the claim pass
// must run post-transform where `__ring_*` decls exist.
import std/rings
import std/io

std/rings:new(ring, capacity: 2) { value: u64 }

std/rings:enqueue(ring, v: 42)
| ok |> std/rings:enqueue(ring, v: 100)
    | ok |> std/rings:enqueue(ring, v: 7)
        | ok |> std/io:print.ln("in")
| full |> std/io:print.ln("ERROR: full")
