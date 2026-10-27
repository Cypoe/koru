// `| live { i: i64 & >=0 }` on the branch is a produce contract — the
// arm promises to emit `i >= 0`. The claims pass discharges it against
// the producing arm's meet joined with the declared field types:
// `i < limit` alone proves nothing below, but `i: i64 & >=0` on the
// field is the invariant the produce may lean on. Checked means the
// payload type is real, not prose.

import std/io
import std/spec

tor tick { i: i64 & >=0, limit: i64 }
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
