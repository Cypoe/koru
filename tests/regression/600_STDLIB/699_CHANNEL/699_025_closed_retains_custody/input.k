// OWED: a `closed` verdict must NOT consume the obligation — custody stays
// with the producer, who disposes inside the `| closed` arm. Same law as
// `full`: only `ok` moves ownership. A dead channel can't eat custody.
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

std/channel:close(inbox)
| ok |> std/io:print.ln("sealed")

mk(i: 9): s |> std/channel:send(inbox, s)
| ok |> std/io:print.ln("sent?!")
| full |> std/io:print.ln("full?!")
| closed |> dispose(s): id |> std/io:print.ln("closed, kept {{ id:d }}")

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump:run(main)
