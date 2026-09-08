// ASPIRATIONAL: per-arm take analysis restores the fast `for` on a query
// whose body does not take.
//
// Same program as 690_300. The take is not in the query; the query only
// prints. When the emitter scopes `may_remove` to the sweep arm and
// verifies the take addresses the cursor, this query is provably
// non-removing and must emit `for (0..len)`. Today it emits `while`
// because the scan is program-wide — that is 690_300, green. This pin
// flips red→green when the analysis lands.

import std/io
import std/store

std/store:new(arena, capacity: 8) { hp: i64 }

std/store:insert(arena) { hp: 1 }
| row a |> std/store:insert(arena) { hp: 2 }
    | row _ |> std/store:take(arena[a])
        | item gone |> std/io:print.ln("took {{ gone.hp:d }}")

std/store:rule(arena)
! row e |> std/io:print.ln("see {{ e.hp:d }}")
