// std/channel x std/supervisor — bounded send, measured composition. `push`
// wraps `std/channel:send` in a same-module tor (the 320_110/111 pattern:
// v1 supervises same-module children only), supervises `| full` with two
// retries, and on exhaustion forwards `full` in kind to the caller's own
// arm. Capacity 2 keeps the channel full across every retry → "gave up".
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

pub tor attempt { r: Reading }
| ok
| full
| closed

attempt = std/channel:send(inbox, r)
| ok => ok
| full => full
| closed => closed

pub tor push { r: Reading }
| ok
| full
| closed

push = attempt(r)
| ok => ok
| full |> std/supervisor:supervised
    | retry t when t < 2
    | exhausted => full
| closed => closed

mk-reading(i: 1, t: 1.0): r1 |> std/channel:send(inbox, r1)
| ok |> mk-reading(i: 2, t: 2.0): r2 |> std/channel:send(inbox, r2)
    | ok |> mk-reading(i: 3, t: 3.0): r3 |> push(r: r3)
        | ok |> std/io:print.ln("ERROR: sent into full channel")
        | full |> std/io:print.ln("gave up")
        | closed |> std/io:print.ln("closed")
    | full |> std/io:print.ln("ERROR: second send full")
    | closed |> std/io:print.ln("send2 closed")
| full |> std/io:print.ln("ERROR: first send full")
| closed |> std/io:print.ln("send1 closed")
