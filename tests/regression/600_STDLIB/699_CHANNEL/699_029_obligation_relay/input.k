// OWED: obligations relay — a consumer arm re-sends its minted value into a
// second channel. Custody chains through vessels: v consumed by the second
// send, minted at the second consumer, discharged there. The ledger threads
// through as many vessel boundaries as the program draws.
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
std/channel:new(outbox, capacity: 8) { src: Src }

std/channel(inbox)
! src v |> std/channel:send(outbox, v)
    | ok |> std/io:print.ln("relayed {{ v.id:d }}")
    | full |> std/io:print.ln("relay full")
    | closed |> std/io:print.ln("relay closed")

std/channel(outbox)
! src v |> dispose(s: v): id |> std/io:print.ln("final {{ id:d }}")

mk(i: 1): s |> std/channel:send(inbox, s)
| ok |> std/channel:close(inbox)
    | ok |> std/channel:close(outbox)
        | ok |> std/io:print.ln("sealed")
| full |> std/io:print.ln("full")
| closed |> std/io:print.ln("closed")

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump(main)
! step |> outbox-step()
! live |> outbox-live()

std/pump:run(main)
