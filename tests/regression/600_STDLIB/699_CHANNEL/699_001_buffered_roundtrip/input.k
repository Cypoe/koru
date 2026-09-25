// std/channel — a buffered channel over a proto-typed element.
// `std/channel:new(inbox, capacity: 16) { reading: Reading }` declares the
// channel: the `{ }` body is the branch table — arm word + payload proto —
// and `std/channel:send`/`recv` answer `| ok | full | closed` and
// `| some v | none | closed`. The pin: one value in, the same value out.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

std/channel:new(inbox, capacity: 16) { reading: Reading }

mk-reading(i: 7, t: 2.5): r |> std/channel:send(inbox, r)
| ok |> std/channel:recv(inbox)
    | some v |> std/io:print.ln("got {{ v.id:d }} {{ v.ts:f }}")
    | none |> std/io:print.ln("none")
    | closed |> std/io:print.ln("recv closed")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("send closed")
