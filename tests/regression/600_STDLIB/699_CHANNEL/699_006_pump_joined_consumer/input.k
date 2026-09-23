// std/channel v1 — a `! recv` arm on the join site is a standing competing
// consumer, compiled into a generated unit the channel's `<name>-step`
// verb drains once per pass. Joined to a pump by the verb convention —
// `! step |> inbox-step()`, `! live |> inbox-live()`, `! wait i |>
// inbox-wait(i)` — the same names a `! step` store exposes. `live`
// answers 0 once the channel is closed AND drained, so `close` is what
// lets this pump drain.
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

std/channel(inbox: Reading, 8)
! recv v |> std/io:print.ln("consumed {{ v.id:d }}")
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
