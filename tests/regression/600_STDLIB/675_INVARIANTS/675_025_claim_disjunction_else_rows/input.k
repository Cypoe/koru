// `or` mirrors: the disjunction's negation IS a conjunction, so the
// ELSE-arm's meet gets every disjunct negated — `i <= 0 or i >= limit`
// gives the live arm `i >= 1` and `i <= limit - 1` outright. Rank
// `limit - i` stays bounded exactly on the second negated row.

import std/io
import std/spec

tor ramp { i: i64, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

ramp = if(i <= 0 or i >= limit)
| then => done i
| else => live { i, limit }

std/spec:claim(atom: terminates, on: ramp) { "rank": "limit - i" }

run = #L ramp(i: 1, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
