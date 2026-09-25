// std/channel — a consumer joins by name, program-wide. `std/channel(inbox)`
// is the bare-reference join (the store/pump family shape): `! reading`
// attaches a consumer arm, `! closed` attaches the close arm; the
// declaration collects them into the drain it emits. The close arm fires
// inside `close` — before its `| ok` continuation — and the consumer arm
// fires from the pump's step.
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
! reading v |> std/io:print.ln("consumed {{ v.id:d }}")
! closed |> std/io:print.ln("inbox closed")

mk-reading(i: 42, t: 4.0): r |> std/channel:send(inbox, r)
| ok |> std/channel:close(inbox)
    | ok |> std/io:print.ln("sent+closed")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("send closed")

std/pump:create(main)
| drained |> std/io:print.ln("pump drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()
! wait i |> inbox-wait(i)

std/pump:run(main)
