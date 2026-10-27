// The declared type IS the base premise: `i: i64 & >=0` on the tor's
// field supplies what the open entry binding cannot — `i: start` gives
// the prover only `i = start` with `start` a caller-scope name, nothing
// about its sign. The base case discharges on the type row alone; the
// step rides the inductive hypothesis as before.

import std/io
import std/spec

tor tick { i: i64 & >=0, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { start: i64 } -> i64

tick = if(i < limit)
| then => live { i, limit }
| else => done i

std/spec:claim(atom: honors, on: tick) { "goal": "i >= 0" }

run = #L tick(i: start, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(start: 0): r |> std/io:print.ln("{{ r:d }}")
