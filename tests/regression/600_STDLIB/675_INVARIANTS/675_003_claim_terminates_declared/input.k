// A `std/spec:claim` is compile-time data, not a runtime step. The
// claims-check pass validates it during analysis — and for `terminates`
// goes on to a judgment: the rank is a linear form over the subject's
// fields, and the prover discharges it at every back-edge by showing
// the guard-seeded meet refutes both "rank stays or grows" and
// "rank falls below zero". The verdict is part of the census —
// `proven` here; `unproven`/`outside-P` name what could not be decided.

import std/io
import std/spec

tor tick { i: i64, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

tick = if(i < limit)
| then => live { i, limit }
| else => done i

std/spec:claim(atom: terminates, on: tick) { "rank": "limit - i" }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
