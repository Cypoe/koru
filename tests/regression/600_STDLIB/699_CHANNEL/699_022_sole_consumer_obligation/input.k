// OWED: obligation transit over a channel, sole consumer. `mk` mints
// `Src<live!>` — a proto value carrying a must-dispose obligation; `send`
// consumes the binding's custody into the vessel; the sole consumer's
// `! src` arm mints `v: Src<live!>` fresh and `dispose` discharges it.
// Exactly-once custody across the ring: the obligation dies at send, is
// reborn at the winning `| some` arm, dies at dispose. The ring carries
// bytes; the ledger carries custody.
import std/io
import std/proto
import std/channel
import std/pump

std/proto(Src) {
    id: i64
}

pub tor mk { i: i64 } -> Src<live!>
mk -> { id: i }

pub tor dispose { s: Src<!live> } -> i64
dispose -> s.id

std/channel:new(inbox, capacity: 8) { src: Src }

std/channel(inbox)
! src v |> dispose(s: v): id |> std/io:print.ln("disposed {{ id:d }}")

mk(i: 1): s |> std/channel:send(inbox, s)
| ok |> std/channel:close(inbox)
    | ok |> std/io:print.ln("sealed")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("closed")

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump:run(main)
