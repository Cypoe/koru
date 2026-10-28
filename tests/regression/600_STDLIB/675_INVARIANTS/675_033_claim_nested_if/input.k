// An arm may chain into a nested dispatch (`| else |> if(…)`): the
// nested arm's premise is outer cases × inner cases — else reads
// `i >= 1`, the inner else reads `i >= n + 1`, and `mid`'s bound on
// rank `i` exists only inside that product. The same meets 675_031
// reaches through `cond` — different spelling, same judgment.

import std/io
import std/spec

tor step { i: i64, n: i64 & >=1 }
| live { i: i64, n: i64 }
| mid { i: i64, n: i64 }
| done i64

tor run { } -> i64

step = if(i <= 0)
| then => done i
| else |> if(i <= n)
  | then => live { i, n }
  | else => mid { i, n }

std/spec:claim(atom: terminates, on: step) { "rank": "i" }

run = #L step(i: 2, n: 5)
| live l |> @L(i: l.i - 1, l.n)
| mid m |> @L(i: m.i - 1, m.n)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
