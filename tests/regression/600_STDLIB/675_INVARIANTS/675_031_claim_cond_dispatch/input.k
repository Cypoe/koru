// A `cond` impl is a first-match cascade: arm i's premise is its own
// guard under every earlier guard's negation. The `mid` arm proves
// only because the fence subtracts `p <= 0` — its clause is
// { i >= 1, i >= n + 1 }, and `i >= 1` is what bounds rank `i` under
// the decrement. Before cond-reading this impl was "not an if-dispatch".

import std/io
import std/spec

tor step { i: i64, n: i64 & >=1 }
| live { i: i64, n: i64 }
| mid { i: i64, n: i64 }
| done i64

tor run { } -> i64

step = cond(i)
| c p when p <= 0 => done i
| c q when q <= n => live { i, n }
| c _ => mid { i, n }

std/spec:claim(atom: terminates, on: step) { "rank": "i" }

run = #L step(i: 2, n: 5)
| live l |> @L(i: l.i - 1, l.n)
| mid m |> @L(i: m.i - 1, m.n)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
