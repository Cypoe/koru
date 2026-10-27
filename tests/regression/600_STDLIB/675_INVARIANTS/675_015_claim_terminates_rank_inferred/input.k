// A `terminates` claim may omit "rank" — the prover then infers rank
// candidates from the subject's own arm guards: a row `Σc·x <= b` is a
// bound the dispatch proved, so `b − Σc·x` is a candidate. The first
// candidate to discharge every back-edge is named in the verdict.

import std/io
import std/spec

tor tick { i: i64, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

tick = if(i < limit)
| then => live { i, limit }
| else => done i

std/spec:claim(atom: terminates, on: tick) { }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
