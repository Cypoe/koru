// The `&&` spelling of the same conjunction: the claims fence reads it
// identically to `and`, and the emit door respells it — `a && b` is
// ambiguous to Zig's parser, so the lowering writes `a and b` with the
// author's spacing riding around it. Same proof as the `and` form:
// rank `i + j` stays bounded on BOTH conjuncts' rows.

import std/io
import std/spec

tor pair { i: i64, j: i64 }
| live { i: i64, j: i64 }
| done i64

tor run { } -> i64

pair = if(i > 0 && j > 0)
| then => live { i, j }
| else => done i

std/spec:claim(atom: terminates, on: pair) { "rank": "i + j" }

run = #L pair(i: 3, j: 5)
| live l |> @L(i: l.i - 1, j: l.j - 1)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
