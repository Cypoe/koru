// 690_367 — a `|>` written at the SAME indent as a `| row` arm is the
// site's second row-produce handler, not a continuation of the arm.
// Refused SHAPE002: two unguarded `row` handlers at one level.
//
// The pin locks two things. The reattachment rule (reattachArmsToLastStep)
// is positional: an arm attaches to the last step BEFORE it at its own
// level, so `| row b` keeps its flat-parse home on insert — before the fix
// the desugar moved the arm UNDER the later `|>` step, and the step's tor
// took the blame (`'__store_write_s' has no branch 'row'`, a
// KORU021 naming the wrong party; a plain `|> std/io:print.ln` produced
// the identical misfire against print.impl).
//
// And the semantics: an unnamed `|>` on inserth IS the `row` handler —
// the single-branch produce arrives unnamed — so `| row b` + `|>` is two
// claims on one produce. `s[b]` could never see `b` there anyway. The
// per-row write this wanted already has a spelling — the arm body:
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
