// OWED: close-with-residue discharges correctly — obligated items stranded
// in the ring at close are still DELIVERED to consumer arms during drain
// (live() stays nonzero until empty), minting <live!> and demanding
// discharge per item. No stranded obligation may die inside the vessel.
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
! src v |> dispose(s: v): id |> std/io:print.ln("drained {{ id:d }}")

mk(i: 1): a |> std/channel:send(inbox, a)
| ok |> mk(i: 2): b |> std/channel:send(inbox, b)
    | ok |> mk(i: 3): c |> std/channel:send(inbox, c)
        | ok |> std/channel:close(inbox)
            | ok |> std/io:print.ln("sealed with residue")
        | full |> std/io:print.ln("full")
        | closed |> std/io:print.ln("closed")
    | full |> std/io:print.ln("full")
    | closed |> std/io:print.ln("closed")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("closed")

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump:run(main)
