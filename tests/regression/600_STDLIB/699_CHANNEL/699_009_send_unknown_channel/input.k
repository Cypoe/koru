// std/channel v1 — a chain step naming a channel that was never declared
// refuses at compile time and names the declaration spelling. Channels are
// comptime-named like stores: there is no dynamic lookup to fail at run.
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
