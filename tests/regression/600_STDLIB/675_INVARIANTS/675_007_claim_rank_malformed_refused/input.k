// `rank` is a linear form — `N`, `name`, `N*name` joined by `+`/`-` — the
// same grammar std/refine's relational atoms speak (one parser, spec-side).
// Anything outside the grammar refuses rather than degrading to prose.

import std/spec

tor step { i: i64, limit: i64 } -> i64

step -> i

std/spec:claim(atom: terminates, on: step) { "rank": "limit * limit" }

step(i: 0, limit: 3)
