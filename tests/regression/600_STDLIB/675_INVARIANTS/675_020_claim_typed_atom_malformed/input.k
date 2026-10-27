// A `&`-atom on a field's type is contract text — one the claims pass
// must be able to read before it may assume it. `fizz` is not a linear
// comparison, so the claim is outside-P with the atom named, rather
// than silently assumed or silently dropped.

import std/io
import std/spec

tor tick { i: i64 & fizz, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

tick = if(i < limit)
| then => live { i, limit }
| else => done i

std/spec:claim(atom: terminates, on: tick) { "rank": "limit - i" }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
