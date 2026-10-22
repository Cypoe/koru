// TEST: kebab in member position resolves as a FIELD name, not subtraction
//
// `p.x-c` applies the same uniform ruling — `x-c` is one name — but member
// names are type-resolved, and the flow checker carries no types, so no
// Koru diagnostic can fire here. The token survives to Zig spelled as a
// member of `p`'s record and the host refuses it: `no field named ...`.
// This is the nbody trap's true home (`c[i].x-c[j]` once parsed as
// field `x-c` on `c[i]`).
//
// The bare BACKEND_COMPILE_ERROR marker is the tripwire (same contract as
// 220_051): it passes only while backend.err carries no `error[KORU…]` —
// a future type-aware member check should land a real diagnostic, and this
// test goes red until that diagnostic is pinned here.

import std/io

tor mk { } -> { x: i64, y: i64 }
mk -> { x: 10, y: 3 }

tor use { p: { x: i64, y: i64 }, c: i64 } -> i64
use -> p.x-c

mk(): p |> use(p, c: 3): r |> std/io:print.ln("{{ r:d }}")
