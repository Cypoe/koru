// The produce contract is checked, not assumed: `live` declares its
// payload `i & >=0`, but nothing in the program establishes it — the
// field is untyped, and the guard `i < limit` bounds from above only.
// The produce may emit `i = -5`; the declared contract may be a lie.
// Refusal is the honest verdict: typed means proved.

import std/io
import std/spec

tor tick { i: i64, limit: i64 }
| live { i: i64 & >=0, limit: i64 }
| done i64

tor run { } -> i64

tick = if(i < limit)
| then => live { i, limit }
| else => done i

std/spec:claim(atom: terminates, on: tick) { }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
