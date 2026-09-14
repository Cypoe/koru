// PINS: a ROW-BINDING read inside a template-frozen `if` under a `! query`
// sweep arm lowers to the threaded row input, on both targets. The per-call
// template pass bakes `if(...)` — condition text and arm bodies included —
// into the invocation's inline_body BEFORE the query transform's walk runs
// (the 690_074 freeze; 690_260 pins the same reach for `! row` rule arms).
// The sweep walk must reach into that frozen text the same way, or the
// emitted sweepbody handler names `e` in a scope where only the
// `__koru_srf_e_*` inputs exist. 690_308 pins `for` under a query arm, but
// its iterable named no row field, so the freeze never mattered there;
// `if(e.owner == …)` is the position that carries the row spelling into the
// baked text — and the `{{ e.id:d }}` in each arm shows the baked arm
// bodies take the same rewrite.
import std/io
import std/store
import std/control

std/store:new(rows, capacity: 4) { id: i64, owner: i64 }

std/store:insert(rows) { id: 7, owner: 1 }
std/store:insert(rows) { id: 9, owner: 0 }

std/store:query(rows)
! query e |> if(e.owner == 1)
    | then |> std/io:print.ln("own {{ e.id:d }}")
    | else |> std/io:print.ln("other {{ e.id:d }}")
