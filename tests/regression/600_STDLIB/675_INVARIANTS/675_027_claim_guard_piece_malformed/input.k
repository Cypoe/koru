// Every conjunct must itself be one linear comparison — `fizz` is
// not a comparison, so the guard is outside-P and says which piece.

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
