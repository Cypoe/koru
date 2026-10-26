// TEST: unspaced `-` between bound names inside an invocation argument
//
// Same ruling as 220_052, one carrier over: `v: q-b` is an argument value,
// and the checker scans argument text. `q-b` reads as one kebab identifier —
// unbound — while `q` and `b` both resolve, so the checker teaches the
// spaced spelling rather than passing `q-b` through to Zig, which would
// read subtraction and produce the right answer for the wrong reason.

import std/io

tor sink { v: i64 } -> i64
sink -> v

tor diff { q: i64, b: i64 } -> i64
diff = sink(v: q-b): r
    |> produce(r)

diff(q: 10, b: 3): r |> std/io:print.ln("{{ r:d }}")
