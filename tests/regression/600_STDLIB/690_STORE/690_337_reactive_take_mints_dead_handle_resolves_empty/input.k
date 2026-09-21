// DEAD-HANDLE RESOLVE — a standing rule that takes its rows fires inside
// `insert` itself (per-row, site-gated to declarations after the rule's
// line), so a `| row h` binding minted by that insert can name a row the
// rule already consumed. The handle carries the slot's CURRENT generation
// — minted after the reactive take bumped it — so the generation check
// alone cannot refuse it. What refuses it: take tombstones
// `hslot_row[gone]` at removal, and `row_of` rejects any resolved dense
// index that is not `< len`. Without those checks this program resolved
// dense row 0 of an emptied store and the second `take` decremented `len`
// past zero — `18446744073709551615` under ReleaseFast, silent corruption.
// The honest answer for a handle whose row is gone is `| empty`.

import std/io
import std/store

std/store:new(pool, capacity: 64) { hp: i64 }

tor sweep {}
sweep = std/store:rule(pool)
! row e |> std/store:take(pool[e])
    | item i |> std/io:print.ln("took {{ i.hp:d }}")

std/store:insert(pool) { hp: 99 }
| row h |> std/store:take(pool[h])
    | item i |> std/io:print.ln("back {{ i.hp:d }}")
    | empty |> std/io:print.ln("empty")

std/io:print.ln("len {{ pool.len:d }}")
