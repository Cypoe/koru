// 690_374 — a nested `! query { [row]s }` destructure REBINDS the row name.
//
// Rule 5 of 690_086: innermost binding wins. The outer sweep's rewrite once
// stopped descending only at a nested `! query` arm with a plain binding —
// a destructure-block rebind was invisible to it, so `s.parent` in the
// inner arm's `when` was rewritten against the OUTER row's projection and
// silently matched (or missed) the wrong row. Pinned: the inner arm rebinds
// `s`, its guard reads the INNER row's parent, and the outer row's own
// `s.v` still rewrites correctly beside it.
import std/io
import std/store

std/store:new(world) { n: 0[i64] }
std/store:new(rows, capacity: 8) { v: i64 }

std/store:insert(rows) { v: 1 }
    | row _ |> std/store:insert(rows) { v: 2 }
        | row _ |> std/store:query(rows)
            ! query { [row]s } when s.v == 1
                |> std/store:query(rows)
                    ! query { [row]s } when s.v == 2
                        |> std/store:stored { world.n: world.n + s.v }
                        |> std/io:print("n {{world.n:d}}\n")
