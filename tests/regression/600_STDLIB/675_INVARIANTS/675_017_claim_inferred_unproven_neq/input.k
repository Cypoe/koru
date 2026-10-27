// A `!=` guard terminates the fold but yields candidates the discharge
// cannot clear: `i != limit` gives the else-arm `i == limit` meet,
// whose negated rows are `i - limit` and `limit - i` — neither is a
// rank the fence can bound below across the back-edge. Honest
// `unproven`, not a guess.

import std/io
import std/spec

tor tick { i: i64, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

tick = if(i != limit)
| then => live { i, limit }
| else => done i

std/spec:claim(atom: terminates, on: tick) { }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
