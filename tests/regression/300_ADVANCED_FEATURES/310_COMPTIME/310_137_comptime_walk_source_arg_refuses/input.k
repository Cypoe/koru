// Pins the named wall a [comptime] subflow impl hits when its body invokes
// a transform: transforms rewrite call-site flows at elaboration, so a raw
// `capture` inside a walked impl body is a Source capture arriving at a
// call evaluator. Before the wall, evalArgs fed the captured text (`v:
// 40[i64]`) to the expression parser — a misleading TrailingGarbage error —
// and earlier still the same program panicked on the emitted-`arg.value`
// splice. The refusal names the boundary: Source params belong to
// transforms, which run at elaboration, not to walkable calls.

import std/io

[comptime] pub tor get-input {} -> i64

[comptime] get-input = capture { v: 40[i64] }
! as a |> captured { v: a.v + 1 }
| captured c => result c.v

[comptime] get-input(): s |> std/io:print.ln("{{ s:d }}")
