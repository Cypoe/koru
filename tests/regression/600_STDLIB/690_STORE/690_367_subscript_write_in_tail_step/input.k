// 690_367 — a `|>` at the same indent as a `| row` arm is insert's JOIN
// (400_210's rule: an unnamed `|>` after a step's arms rejoins after the
// dispatch, for every tor). Arm bindings are arm-local — `b` is invisible
// at the join, so `s[b]` cannot resolve there. Attachment stays positional:
// `| row b` dispatches on insert, the step before it.
//
// No koruc-level unbound-reference check exists yet (the same hole 320_152
// lives in): today the refusal is the host's `use of undeclared identifier
// 'b'` from the emitted Zig.
//
// The per-row write this wanted already has a spelling — the arm body:
//
//     | row b |> std/store:stored { w.h: a }
//         |> std/store:stored { s[b].p: a }
//
// which compiles and prints `p 33554432 v 2` (measured same day).
//
// Surfaced by koru-libs/metal folder.k: the insert-seeding cascade wanted
// `|> stored { res[c8].parent: hf }` after the final `| row` arm.

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
