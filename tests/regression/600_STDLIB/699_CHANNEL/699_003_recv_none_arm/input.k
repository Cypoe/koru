// std/channel v1 — the `| none` arm answers a recv on an empty, still-open
// channel. Go needs `select` + `default` for this; here emptiness is a named
// branch. A send between two recvs flips the second to `| some`.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

std/channel(inbox: Reading, 4)

std/channel:recv(inbox)
| some v |> std/io:print.ln("unexpected {{ v.id:d }}")
| none |> std/io:print.ln("first none")
| closed |> std/io:print.ln("first closed")

mk-reading(i: 9, t: 9.0): r |> std/channel:send(inbox, r)
| ok |> std/channel:recv(inbox)
    | some v |> std/io:print.ln("second got {{ v.id:d }}")
    | none |> std/io:print.ln("second none")
    | closed |> std/io:print.ln("second closed")
| full |> std/io:print.ln("send full")
| closed |> std/io:print.ln("send closed")
