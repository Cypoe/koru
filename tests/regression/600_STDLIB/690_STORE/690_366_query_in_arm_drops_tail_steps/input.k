// 690_366 — steps chained AFTER a std/store:query step inside an arm
// body must not be silently dropped.
//
// At top level the same shape is refused (KORU161: exactly one `! query`
// branch per site — the query owns its continuation). Inside an arm body
// the tail silently vanishes: the query's sweep emits, but the trailing
// `|> std/io:print.ln("after")` never reaches the output — no run, no
// refusal, no diagnostic. Either outcome (run the tail, or refuse it
// like the top-level form) is defensible; silently dropping it is a
// miscompile.
//
// Surfaced by koru-libs/metal tilt_snap.k: scripted `|> if` steps after
// a query inside a `! frame` arm never fired — the scenario hung with
// nothing emitted and nothing refusing.

import std/store
import std/io
import lib/pump

std/store:new(s, capacity: 4) { v: i64 }
std/store:insert(s) { v: 1 }
| row _ |> _

lib/pump:fire()
    ! bang
        |> std/store:query(s)
            ! query r |> std/store:stored { r.v: r.v + 1 }
        |> std/io:print.ln("after")
    | done |> std/io:print.ln("done")
