// std/channel v1 — a buffered channel over a proto-typed element.
// `std/channel(inbox: Reading, 16)` declares the channel (Vyukov ring +
// channel-owned closed bit); `std/channel:send` answers `| ok | full |
// closed`, `std/channel:recv` answers `| some v | none | closed`. The pin:
// one value in, the same value out, fields intact.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

std/channel(inbox: Reading, 16)

mk-reading(i: 7, t: 2.5): r |> std/channel:send(inbox, r)
| ok |> std/channel:recv(inbox)
    | some v |> std/io:print.ln("got {{ v.id:d }} {{ v.ts:f }}")
    | none |> std/io:print.ln("none")
    | closed |> std/io:print.ln("recv closed")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("send closed")
