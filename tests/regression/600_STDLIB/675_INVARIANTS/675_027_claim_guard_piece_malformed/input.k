// A nested `or` case-splits through the conjunction:
// `i > 0 and (j > 0 or i < 0)` gives cases {i>0, j>0} and {i>0, i<0} —
// the second is empty (FM finds it infeasible) and discharges
// vacuously. What remains is a real proof: inferred rank `i` clears
// the one surviving case.

import std/io
import std/spec

tor bad { i: i64, j: i64 }
| live { i: i64, j: i64 }
| done i64

tor run { } -> i64

bad = if(i > 0 and (j > 0 or i < 0))
| then => live { i, j }
| else => done i

std/spec:claim(atom: terminates, on: bad) { }

run = #L bad(i: 3, j: 5)
| live l |> @L(i: l.i - 1, j: l.j - 1)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
