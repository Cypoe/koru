// `recv` on a kind whose proto carries owned leaves must refuse: `| some v`
// binds the bare payload with no mint, and per-path debts only exist where
// the obligate step runs — the `!` arm. Composite custody consumes by arms
// (699_031); recv is the shape that can't see them.
import std/io
import std/proto
import std/channel
import std/pump
import app/lib/res

std/proto(Env) {
    r1: *app/lib/res:Resource<owned!>
    r2: *app/lib/res:Resource<owned!>
}

std/channel:new(inbox, capacity: 8) { env: Env }

std/channel:recv(inbox)
| some v |> std/io:print.ln("got")
| none |> std/io:print.ln("none")
| closed |> std/io:print.ln("closed")
