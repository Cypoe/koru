// Pins TODAY's program-wide take-scan: any `take` on a store anywhere
// makes every query of it emit the removal-tolerant `while`.
//
// The take here is NOT in the query body — it addresses a handle from
// insert, then a later top-level `rule` only prints. `query` is a
// different loop (already `for`); the program-wide take-scan lives
// on the rule/qsweep path. The emitter never checks that
// a body's take targets its own cursor; one unrelated take is enough.
// 690_031 pins current-row take inside a query (the contract the while
// is exact under). This pin is the other face: the slow loop where it
// is not needed.
//
// Dies when per-arm analysis lands; 690_301 is the replacement.

import std/io
import std/store

std/store:new(arena, capacity: 8) { hp: i64 }

std/store:insert(arena) { hp: 1 }
| row a |> std/store:insert(arena) { hp: 2 }
    | row _ |> std/store:take(arena[a])
        | item gone |> std/io:print.ln("took {{ gone.hp:d }}")

std/store:rule(arena)
! row e |> std/io:print.ln("see {{ e.hp:d }}")
