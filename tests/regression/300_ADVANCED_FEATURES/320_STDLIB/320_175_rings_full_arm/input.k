// std/rings — the `| full` arm is the backpressure surface: a bounded
// ring refuses the enqueue that would exceed capacity instead of
// growing silently. Capacity 2, three enqueues — the third fires full.
import std/rings
import std/io

std/rings:new(q, capacity: 2) { value: u64 }

std/rings:enqueue(q, v: 1)
| ok |> std/rings:enqueue(q, v: 2)
    | ok |> std/rings:enqueue(q, v: 3)
        | ok |> std/io:print.ln("ERROR: third enqueue accepted")
        | full |> std/io:print.ln("full at capacity")
    | full |> std/io:print.ln("ERROR: early full")
| full |> std/io:print.ln("ERROR: early full")
