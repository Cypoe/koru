// std/channel — a send after close lands `| closed`, not `| ok`.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

std/channel:new(inbox, capacity: 4) { reading: Reading }

std/channel:close(inbox)
| ok |> mk-reading(i: 5, t: 5.0): r |> std/channel:send(inbox, r)
    | ok |> std/io:print.ln("send ok")
    | full |> std/io:print.ln("send full")
    | closed |> std/io:print.ln("send refused: closed")
