// OWED: `std/supervisor` on a std/channel verb directly. `push`'s child is
// `std/channel:send` — a foreign-module transform verb; v1 supervises
// same-module children only, and `| retry |> send(...)` is cross-module
// re-entry. The channel twin of 320_113.
import std/io
import std/proto
import std/channel
import std/supervisor

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

std/channel:new(inbox, capacity: 2) { reading: Reading }

pub tor push { r: Reading }
| ok
| full
| closed

push = std/channel:send(inbox, r)
| ok => ok
| full |> std/supervisor:supervised
    | retry t when t < 2 |> std/channel:send(inbox, r)
    | exhausted => full
| closed => closed

mk-reading(i: 1, t: 1.0): r |> push(r)
| ok |> std/io:print.ln("in")
| full |> std/io:print.ln("gave up")
| closed |> std/io:print.ln("closed")
