// std/channel v1 — send after close answers `| closed`, not a panic.
// Go panics on send-to-closed; here the refusal is a named branch the
// caller handles. The `| ok` on close is the close acknowledgment.
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

std/channel:close(inbox)
| ok |> mk-reading(i: 5, t: 5.0): r |> std/channel:send(inbox, r)
    | ok |> std/io:print.ln("send ok")
    | full |> std/io:print.ln("send full")
    | closed |> std/io:print.ln("send refused: closed")
