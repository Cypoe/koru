// The fence reads a cond whose scrutinee is one integer field. A
// scrutinee that is a linear form is a named outside-P — honest,
// never guessed. The program still compiles and runs.

import std/io
import std/spec

tor step { i: i64 }
| live i64
| done i64

tor run { } -> i64

step = cond(i + 1)
| c p when p > 0 => live i
| c _ => done i

std/spec:claim(atom: terminates, on: step) { "rank": "i" }

run = #L step(i: 2)
| live l |> @L(i: l - 1)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
