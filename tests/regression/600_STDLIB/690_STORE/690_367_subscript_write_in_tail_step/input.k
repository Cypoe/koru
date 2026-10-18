// 690_367 — a chain-level `|>` continuation (aligned with the `| row`
// arm) carrying a subscript write is refused, while the same step inside
// the arm body compiles and runs.
//
//   error[KORU021]: '__store_write_s' has no branch 'row'
//
// Chain continuations after a `| row` arm are ordinary: `| row _ |> insert`
// seeds rows in every corpus program. But `|> stored { s[b].p: a }` at
// that position mints `__store_write_s` without a `row` branch — position
// silently deciding which branches the write handler carries is the
// defect. Either the continuation form must address rows like the
// arm-body form does, or the refusal must name the positional rule.
//
// Surfaced by koru-libs/metal folder.k: the insert-seeding cascade wanted
// `|> stored { res[c8].parent: hf }` after the final `| row` arm.
//
// Expected: p of row b = a's handle (slot 0, brand 2 => 33554432).

import std/store
import std/io

std/store:new(w) { h: 0[i64] }
std/store:new(s, capacity: 4) { p: i64, v: i64 }

std/store:insert(s) { p: 0, v: 1 }
| row a |> std/store:insert(s) { p: 0, v: 2 }
    | row b |> std/store:stored { w.h: a }
    |> std/store:stored { s[b].p: a }

std/store:query(s)
! query r |> std/io:print.ln("p {{ r.p:d }} v {{ r.v:d }}")
