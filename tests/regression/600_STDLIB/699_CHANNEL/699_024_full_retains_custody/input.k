// OWED: a `full` verdict must NOT consume the obligation — custody stays
// with the producer, who disposes it inside the `| full` arm. The verdict
// IS the custody transfer point: only `ok` moves ownership into the vessel.
// capacity 2, two sends fill the ring, the third answers full and the
// producer disposes s3 itself. Proves failed sends can't strand custody.
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

std/channel:new(inbox, capacity: 2) { src: Src }

std/channel(inbox)
! src v |> dispose(s: v): id |> std/io:print.ln("disposed {{ id:d }}")

mk(i: 1): a |> std/channel:send(inbox, a)
| ok |> mk(i: 2): b |> std/channel:send(inbox, b)
    | ok |> mk(i: 3): c |> std/channel:send(inbox, c)
        | ok |> std/io:print.ln("c sent")
        | full |> dispose(s: c): id |> std/io:print.ln("full, kept {{ id:d }}")
        | closed |> std/io:print.ln("closed")
    | full |> std/io:print.ln("b full")
    | closed |> std/io:print.ln("closed")
| full |> std/io:print.ln("a full")
| closed |> std/io:print.ln("closed")

std/channel:close(inbox)
| ok |> std/io:print.ln("sealed")

std/pump:create(main)
| drained |> std/io:print.ln("drained")

std/pump(main)
! step |> inbox-step()
! live |> inbox-live()

std/pump:run(main)
