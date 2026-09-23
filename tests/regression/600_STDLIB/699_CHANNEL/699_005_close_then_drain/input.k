// std/channel v1 — close does not strand buffered values. Two sends land,
// `close` seals the channel, and the drain still reads `| some` twice
// before `| closed` answers — Go's `v, ok` drain idiom as named branches.
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

mk-reading(i: 11, t: 1.0): r1 |> std/channel:send(inbox, r1)
| ok |> mk-reading(i: 22, t: 2.0): r2 |> std/channel:send(inbox, r2)
    | ok |> std/channel:close(inbox)
        | ok |> std/channel:recv(inbox)
            | some a |> std/io:print.ln("drain {{ a.id:d }}") |> std/channel:recv(inbox)
                | some b |> std/io:print.ln("drain {{ b.id:d }}") |> std/channel:recv(inbox)
                    | some c |> std/io:print.ln("unexpected {{ c.id:d }}")
                    | none |> std/io:print.ln("none after drain")
                    | closed |> std/io:print.ln("closed after drain")
                | none |> std/io:print.ln("none too early")
                | closed |> std/io:print.ln("closed too early")
            | none |> std/io:print.ln("none first")
            | closed |> std/io:print.ln("closed first")
    | full |> std/io:print.ln("send2 full")
    | closed |> std/io:print.ln("send2 closed")
| full |> std/io:print.ln("send1 full")
| closed |> std/io:print.ln("send1 closed")
