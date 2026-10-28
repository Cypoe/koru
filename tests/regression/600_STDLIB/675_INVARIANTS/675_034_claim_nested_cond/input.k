// A chained `cond` is the same reading one level down: outer else
// gives `i >= 1`, the inner cascade's first-match subtraction gives
// `mid` `i >= 1 ∧ n < i`. Rank `i` clears every surviving clause.

import std/io
import std/spec

tor step { i: i64, n: i64 & >=1 }
| live { i: i64, n: i64 }
| mid { i: i64, n: i64 }
| done i64

tor run { } -> i64

step = if(i <= 0)
| then => done i
| else |> cond(n)
  | c m when m >= i => live { i, n }
  | c _ => mid { i, n }

std/spec:claim(atom: terminates, on: step) { "rank": "i" }

run = #L step(i: 2, n: 5)
| live l |> @L(i: l.i - 1, l.n)
| mid m |> @L(i: m.i - 1, m.n)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
