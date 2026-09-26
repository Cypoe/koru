// Pins the compatibility gate on the enclosing-arm claim: name match is
// not enough. `push` declares `full string` — its arm binds `f`. The
// nested `std/rings:enqueue` produces a VOID `full`, which cannot supply
// `f` — the claim must refuse and the two-line spelling stays mandatory.
// Green today AND after the claim pass lands: this is the "two lines when
// incompatible" invariant.
import std/rings
import std/io

std/rings:new(ring, capacity: 2) { value: u64 }

pub tor push { v: u64 }
| ok
| full string

push = std/rings:enqueue(ring, v)
| ok => ok
| full => full "ring is full"

push(v: 42)
| ok |> std/rings:enqueue(ring, v: 100)
    | ok |> std/io:print.ln("in")
| full f |> std/io:print.ln("{{ f:s }}")
