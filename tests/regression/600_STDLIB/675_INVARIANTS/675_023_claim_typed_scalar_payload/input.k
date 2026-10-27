// Scalar payloads carry the same produce contract: `| live i64 & >=0`
// promises a non-negative produced value, and the scalar's implicit
// self is the produced field. `done`'s contract discharges under the
// else-meet `i == 0` outright; `live`'s leans on the field's own
// `i & >=0`. Two typed arms, two established contracts.

import std/io
import std/spec

tor drop { i: i64 & >=0 }
| live i64 & >=0
| done i64 & >=0

tor run { } -> i64

drop = if(i != 0)
| then => live i
| else => done i

std/spec:claim(atom: terminates, on: drop) { }

run = #L drop(i: 3)
| live l |> @L(i: l - 1)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
