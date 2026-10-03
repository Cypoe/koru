// The bug: send consumes s's custody, then the producer touches it again.
// 699_026 pins this refusal; this cell re-derives it outside the suite.

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
