// std/channel — two `std/channel(inbox)` joins are two competing consumers:
// statically enumerable, each value goes to exactly one unit, join order.
// Two sends → the first unit takes the first value, the second the next.
import std/io
import std/proto
import std/channel
import std/pump

std/proto(Reading) {
    id: u64
    ts: f64
}

pub tor mk-reading { i: u64, t: f64 } -> Reading
mk-reading -> { id: i, ts: t }

std/channel:new(inbox, capacity: 8) { reading: Reading }

std/channel(inbox)
! reading v |> std/io:print.ln("c0 got {{ v.id:d }}")

std/channel(inbox)
! reading v |> std/io:print.ln("c1 got {{ v.id:d }}")

std/channel(inbox)
! closed |> std/io:print.ln("inbox closed")

mk-reading(i: 1, t: 1.0): r1 |> std/channel:send(inbox, r1)
| ok |> mk-reading(i: 2, t: 2.0): r2 |> std/channel:send(inbox, r2)
    | ok |> std/channel:close(inbox)
        | ok |> std/io:print.ln("sealed")
    | full |> std/io:print.ln("full")
    | closed |> std/io:print.ln("send2 closed")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("send1 closed")

std/pump:create(main)
| drained |> std/io:print.ln("pump drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump:run(main)
