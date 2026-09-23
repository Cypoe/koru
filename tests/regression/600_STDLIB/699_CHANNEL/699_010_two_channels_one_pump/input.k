// std/channel v1 — the select answer: two channels joined to one pump, each
// with its own `! recv` consumer. The pump steps both participants in join
// order — a statically resolved multi-channel wait with no runtime
// `selectgo`. One value per channel, both close, pump drains.
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

std/channel(left: Reading, 8)
! recv v |> std/io:print.ln("left {{ v.id:d }}")

std/channel(right: Reading, 8)
! recv v |> std/io:print.ln("right {{ v.id:d }}")

mk-reading(i: 100, t: 1.0): a |> std/channel:send(left, a)
| ok |> mk-reading(i: 200, t: 2.0): b |> std/channel:send(right, b)
    | ok |> std/channel:close(left)
        | ok |> std/channel:close(right)
            | ok |> std/io:print.ln("both sealed")
    | full |> std/io:print.ln("send2 full")
    | closed |> std/io:print.ln("send2 closed")
| full |> std/io:print.ln("send1 full")
| closed |> std/io:print.ln("send1 closed")

std/pump:create(main)
| drained |> std/io:print.ln("pump drained")

std/pump(main)
! step |> left-step()
! live |> left-live()

std/pump(main)
! step |> right-step()
! live |> right-live()

std/pump:run(main)
