// TEST: record literals in call-arg position reach Zig unlowered — tripwire
//
// `use(p: { x: 10, y: 3 })` emits the literal verbatim —
// `{ x: 10, y: 3 }` — which is Koru record syntax, not Zig; the host dies
// `expected 'while', 'for', 'inline', or '{'`. Bare-return literals DO
// lower (`mk -> { x: 10 }` emits `.{ .x = 10 }`) — the arg-position inline
// path skips that lowering entirely. Not kebab-specific: plain names fail
// identically.
//
// Whether arg literals are intended grammar at all is a language question —
// either way a raw host error is wrong (legal → lower it; illegal → refuse
// in the frontend). Bare BACKEND_COMPILE_ERROR pins the honest failure
// until the call is made (220_051 contract).

import std/io

tor use { p: { x: i64, y: i64 } } -> i64
use -> p.x

use(p: { x: 10, y: 3 }): r |> std/io:print.ln("{{ r:d }}")
