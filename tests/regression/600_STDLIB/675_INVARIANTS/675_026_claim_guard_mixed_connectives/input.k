// One connective level only: `a and b or c` has no single top-level
// reading the fence can take, so it is outside-P — the program still
// compiles and runs; the claim just reports what it cannot judge.

import std/io
import std/spec

tor mix { i: i64, j: i64 }
| live { i: i64, j: i64 }
| done i64

tor run { } -> i64

mix = if(i > 0 and j > 0 or i < 0)
| then => live { i, j }
| else => done i

std/spec:claim(atom: terminates, on: mix) { }

run = #L mix(i: 3, j: 5)
| live l |> @L(i: l.i - 1, j: l.j - 1)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
