// std/channel — `| full` answers a send into a saturated buffer.
// Capacity 2: two sends land `| ok`, the third lands `| full`, then one
// recv drains a slot and the retry would land `| ok` again.
import std/io
import std/proto
import std/channel

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

std/channel:new(inbox, capacity: 2) { reading: Reading }

mk-reading(i: 1, t: 1.0): r1 |> std/channel:send(inbox, r1)
| ok |> mk-reading(i: 2, t: 2.0): r2 |> std/channel:send(inbox, r2)
    | ok |> mk-reading(i: 3, t: 3.0): r3 |> std/channel:send(inbox, r3)
        | ok |> std/io:print.ln("send3 ok")
        | full |> std/io:print.ln("send3 full")
        | closed |> std/io:print.ln("send3 closed")
    | full |> std/io:print.ln("send2 full")
    | closed |> std/io:print.ln("send2 closed")
| full |> std/io:print.ln("send1 full")
| closed |> std/io:print.ln("send1 closed")

std/channel:recv(inbox)
| some v |> std/io:print.ln("drained {{ v.id:d }}")
| none |> std/io:print.ln("none")
| closed |> std/io:print.ln("closed")
