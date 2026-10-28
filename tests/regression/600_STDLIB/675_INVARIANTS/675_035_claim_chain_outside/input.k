// A chain that is not `if`/`cond` is not a dispatch the fence can
// read — it names itself outside-P rather than guessing a premise.
// The program still compiles and runs.

import std/io
import std/spec

tor step { i: i64 }
| live i64
| done i64

tor bounce { x: i64 }
| live i64
| done i64

tor run { } -> i64

bounce = if(x <= 0)
| then => done x
| else => live x

step = if(i <= 0)
| then => done i
| else |> bounce(x: i)
  | live v => live v
  | done v => done v

std/spec:claim(atom: terminates, on: step) { "rank": "i" }

run = #L step(i: 2)
| live l |> @L(i: l - 1)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
