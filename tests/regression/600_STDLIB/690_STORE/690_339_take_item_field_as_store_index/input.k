// A `| item` arm binds the taken row VALUE, so a store-field member of it
// used as an index — `pool[i.opp]` — resolves the field's stored handle.
// The self-FK traversal head (`store[handle.field]` = "field OF row
// handle") must NOT fire on a row-value base: `i` is not a handle.
//
// Shape: two rows, the first's `opp` column carrying the second's minted
// handle. Taking row a swap-removes it (b slides to slot 0 — the handle
// still resolves), then `pool[i.opp].hp: 99` writes the survivor through
// the taken payload's stored handle. Sweep prints the lone row: 99.

import std/io
import std/store

std/store:new(pool, capacity: 8) { hp: i64, opp: i64 }

std/store:insert(pool) { hp: 10, opp: -1 }
| row a |> std/store:insert(pool) { hp: 20, opp: -1 }
    | row b |> std/store:stored { pool[a].opp: b } |> std/store:take(pool[a])
        | item i |> std/store:stored { pool[i.opp].hp: 99 }
        | empty |> _

std/store:query(pool)
! query e |> std/io:print.ln("hp {{ e.hp:d }}")
