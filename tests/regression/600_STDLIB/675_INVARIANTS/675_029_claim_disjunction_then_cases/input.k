// An `or` guard gives the THEN-arm a case set — `i <= 0 or i <= limit - 1`
// splits into two meets, and the rank must clear BOTH: case `i <= 0`
// bounds `limit - i` only through the declared `limit & >=1`, case
// `i <= limit - 1` bounds it outright. Before case-meets the then-arm
// of a disjunction held nothing and this was unproven.

import std/io
import std/spec

tor climb { i: i64, limit: i64 & >=1 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

climb = if(i <= 0 or i <= limit - 1)
| then => live { i, limit }
| else => done i

std/spec:claim(atom: terminates, on: climb) { "rank": "limit - i" }

run = #L climb(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
