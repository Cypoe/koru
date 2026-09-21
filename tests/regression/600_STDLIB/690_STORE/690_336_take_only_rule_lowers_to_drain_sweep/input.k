// DRAIN SWEEP — a rule whose entire `! row` body is `take(s[e])` with a
// discarded `| item` payload removes every row the invoked sweep visits.
// The per-row take reads every column into the item payload and swap-writes
// every column of the last row into the freed slot — work that exists for
// the payload's sake and to keep survivors live. A drain has neither, so
// the invoked sweep lowers to take's bookkeeping alone: freelist push,
// generation bump, hslot/row_hslot fixup, len decrement — no column
// traffic. Slot-reuse order after a refill IS observable (handles are
// i64s), so the lowering reproduces sequential take's freelist order
// rather than `clear`'s canonical reset.
//
// `pool` qualifies: bare take on the bound row, discard item arm, no
// guard, no owned columns, no `! removed` observer, no index.
// `guarded` declines: a `when` clause makes the walk selective — it keeps
// the removal-tolerant `while` that re-checks the index swap-remove just
// refilled.
//
// Inserts sit above the rule declarations so the reactive per-insert fire
// (`__site_line > rule line`) stays out of the picture — the sweeps run
// only when the named rules are invoked.

import std/io
import std/store

std/store:new(pool, capacity: 64) { hp: i64 }
std/store:new(guarded, capacity: 64) { hp: i64 }

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

tor drain-pool {}
drain-pool = std/store:rule(pool)
! row e |> std/store:take(pool[e])
    | item _ |> _

tor sweep-guarded {}
sweep-guarded = std/store:rule(guarded)
! row e when e.hp <= 10 |> std/store:take(guarded[e])
    | item _ |> _

drain-pool()
sweep-guarded()

std/io:print.ln("pool {{ pool.len:d }}")
std/io:print.ln("guarded {{ guarded.len:d }}")
