// OWED refusal: after `send(inbox, s)` consumes s's <live!> custody into the
// vessel, the producer's binding is dead — touching `s` again must refuse.
// Poisoning at the boundary is the whole point: nothing the producer does
// after send can reach the value the consumer now owns.
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

pub tor peek { s: Src<live> } -> i64
peek -> s.id

std/channel:new(inbox, capacity: 8) { src: Src }

std/channel(inbox)
! src v |> dispose(s: v): id |> std/io:print.ln("disposed {{ id:d }}")

mk(i: 1): s |> std/channel:send(inbox, s)
| ok |> peek(s): id |> std/io:print.ln("poisoned read {{ id:d }}")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("closed")

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump:run(main)
