// OWED refusal: a `! src` arm receiving an obligated value must discharge
// it — `v: Src<live!>` minted at delivery cannot silently drop. Reading the
// payload is fine; abandoning custody is not. The obligation system reaches
// across the ring to the receive side — that is the entire point.
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
! src v |> std/io:print.ln("leaked {{ v.id:d }}")

mk(i: 1): s |> std/channel:send(inbox, s)
| ok |> std/io:print.ln("sent")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("closed")

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump:run(main)
