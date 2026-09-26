// DRAIN SWEEP — a rule whose entire `! row` body is `take(s[e])` with a
// discarded `| item` payload removes every row the invoked sweep visits.
// The per-row take reads every column into the item payload and swap-writes
// every column of the last row into the freed slot — work that exists for
// the payload's sake and to keep survivors live. A drain has neither, so
// the invoked sweep lowers to the clear unit's canonical reset: a
// generation bump over every issued slot (`0..hslot_next`), then len,
// freelist and the fresh cursor drop to zero and `ident` re-arms — no
// column traffic. Refilled rows take slots in fresh order rather than
// sequential take's LIFO pop order — observable only in handle bit
// values; the slot SET reissued is identical.
//
// `pool` qualifies: bare take on the bound row, discard item arm, no
// guard, no owned columns, no `! removed` observer.
// `guarded` declines: a `when` clause makes the walk selective — it keeps
// the removal-tolerant `while` that re-checks the index swap-remove just
// refilled.
// `ipool` qualifies WITH an index: take reseats nothing in the bucket
// map (dead handles resolve to no live row), so a teardown leaves the
// index exactly as sequential take would — and the pin proves it by
// routing a lookup over the drained store and again after a refill.
//
// Inserts sit above the rule declarations so the reactive per-insert fire
// (`__site_line > rule line`) stays out of the picture — the sweeps run
// only when the named rules are invoked.

import std/io
import std/store
import std/indexes

std/store:new(pool, capacity: 64) { hp: i64 }
std/store:new(guarded, capacity: 64) { hp: i64 }
std/store:new(ipool, capacity: 64) { tag: i64, hp: i64 }
std/indexes:store(ipool, tag)

std/store:insert(pool) { hp: 5 }
| row _ |> _
| full |> _
std/store:insert(pool) { hp: 50 }
| row _ |> _
| full |> _
std/store:insert(pool) { hp: 8 }
| row _ |> _
| full |> _

std/store:insert(guarded) { hp: 5 }
| row _ |> _
| full |> _
std/store:insert(guarded) { hp: 50 }
| row _ |> _
| full |> _
std/store:insert(guarded) { hp: 8 }
| row _ |> _
| full |> _

std/store:insert(ipool) { tag: 1, hp: 5 }
| row _ |> _
| full |> _
std/store:insert(ipool) { tag: 2, hp: 50 }
| row _ |> _
| full |> _

tor drain-pool {}
drain-pool = std/store:rule(pool)
! row e |> std/store:take(pool[e])
    | item _ |> _

tor sweep-guarded {}
sweep-guarded = std/store:rule(guarded)
! row e when e.hp <= 10 |> std/store:take(guarded[e])
    | item _ |> _

tor drain-ipool {}
drain-ipool = std/store:rule(ipool)
! row e |> std/store:take(ipool[e])
    | item _ |> _

drain-pool()
sweep-guarded()
drain-ipool()

std/io:print.ln("pool {{ pool.len:d }}")
std/io:print.ln("guarded {{ guarded.len:d }}")
std/io:print.ln("ipool {{ ipool.len:d }}")

// a routed lookup over the drained store answers none — the bucket's
// dead members skip, never resolve
std/store:query(ipool)
    ! first p when p.tag == 1 |> std/io:print.ln("stale {{ p.hp:d }}")
    | none |> std/io:print.ln("ipool drained")

// a standing rule still stands: drain lowered the sweep, not the enters —
// this insert (site line past the rule's) fires the take body and the
// new row dies instantly, so the routed lookup still answers none
std/store:insert(ipool) { tag: 2, hp: 99 }
| row _ |> _
| full |> _
std/io:print.ln("after-refill {{ ipool.len:d }}")
std/store:query(ipool)
    ! first p when p.tag == 2 |> std/io:print.ln("stale {{ p.hp:d }}")
    | none |> std/io:print.ln("rule still stands")
