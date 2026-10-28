// De Morgan splits the ELSE-arm too: `i > 0 and i >= limit` negates to
// `i <= 0 or i < limit` — two else-cases. Rank `limit - i` clears the
// first through `limit & >=1` (i <= 0 gives i' <= 1 <= limit) and the
// second outright (i < limit gives i' <= limit). Before case-meets the
// else-arm of a conjunction held nothing and this was unproven.

import std/io
import std/spec

tor climb { i: i64, limit: i64 & >=1 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

climb = if(i > 0 and i >= limit)
| then => done i
| else => live { i, limit }

std/spec:claim(atom: terminates, on: climb) { "rank": "limit - i" }

run = #L climb(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
