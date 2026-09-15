// `! first <row> when <cond>` on std/store:query runs its body on the FIRST
// matching row and stops the sweep — one visit, not one per match. `| none`
// runs its body when no row matches. The pair is the find-or-join spelling:
// a `! query` sweep visits every row, so "find the one row named by a key"
// scans the whole store and emulates the absent case with a sentinel.
//
// Two rows satisfy `n >= 2`; the pin is that the body fires ONCE — the early
// exit is the semantics, not an optimization. `| none` is the established
// absent-case arm (320_090, 220_012).

import std/store
import std/io

std/store:new(items, capacity: 16) { n: i32 }

for(0..4)
! each k |> std/store:insert(items) { n: @as(i32, @intCast(k)) }

std/store:query(items)
    ! first e when e.n >= 2 |> std/io:print.ln("hit {{ e.n:d }}")
    | none |> std/io:print.ln("none")

std/store:query(items)
    ! first e when e.n == 9 |> std/io:print.ln("hit {{ e.n:d }}")
    | none |> std/io:print.ln("none")
