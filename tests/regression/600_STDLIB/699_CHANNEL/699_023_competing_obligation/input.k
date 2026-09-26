// OWED: obligation transit under COMPETING consumers. Two `std/channel(inbox)`
// joins race each `! src` pop — exactly-once delivery means whichever unit
// wins the slot mints `v: Src<live!>` and must discharge it. Competition is
// safe: the ledger needs one winner and every arm checked, not a named
// endpoint. Sibling of 699_007 (plain competition) and 699_022 (sole transit).
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
! src v |> dispose(s: v): id |> std/io:print.ln("c0 disposed {{ id:d }}")

std/channel(inbox)
! src v |> dispose(s: v): id |> std/io:print.ln("c1 disposed {{ id:d }}")

mk(i: 1): a |> std/channel:send(inbox, a)
| ok |> mk(i: 2): b |> std/channel:send(inbox, b)
    | ok |> std/channel:close(inbox)
        | ok |> std/io:print.ln("sealed")
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
