// std/channel — a chain step naming a channel nobody declared refuses by
// name and spells the declaration.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

mk-reading(i: 1, t: 1.0): r |> std/channel:send(ghost, r)
| ok |> std/io:print.ln("sent")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("closed")
