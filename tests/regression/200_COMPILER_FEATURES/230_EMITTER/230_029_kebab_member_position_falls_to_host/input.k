// TEST: kebab in member position lands KORU182 — was a raw host error
//
// `p.x-c` applies the same uniform ruling — `x-c` is one name — but member
// names resolve against a TYPE, not the scope map. This used to sail past
// the checker and die in Zig as `no field named 'x_3'`. Now the flow
// checker enumerates the receiver's field set (impl input params, `|branch`
// payload bindings, kernel `| computed` / `| kernel` bindings) and fires
// KORU182 when the `-`-joined name is no field but its first segment IS and
// the rest resolve as names — the subtraction the author almost surely
// meant. This is the nbody trap's true home (`c[i].x-c[j]` parsed as field
// `x-c` on `c[i]`).
//
// Declared kebab fields stay legal member spellings — `x-c` in the field
// set exits silently. Receivers whose types don't statically enumerate
// (scalars, host types, `.len`-style builtins) decline and keep the host's
// check — conservative.

import std/io

tor mk { } -> { x: i64, y: i64 }
mk -> { x: 10, y: 3 }

tor use { p: { x: i64, y: i64 }, c: i64 } -> i64
use -> p.x-c

mk(): p |> use(p, c: 3): r |> std/io:print.ln("{{ r:d }}")
