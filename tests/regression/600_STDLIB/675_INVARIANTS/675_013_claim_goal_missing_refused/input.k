// `honors` requires a "goal" field — the invariant it claims the fold
// preserves. An honors claim without one names nothing to check;
// the pass refuses and names the missing field.

import std/spec

tor step { i: i64, limit: i64 } -> i64

step -> i

std/spec:claim(atom: honors, on: step) { "rank": "limit - i" }

step(i: 0, limit: 3)
