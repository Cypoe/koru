// `and` in the impl guard is a conjunction: the then-arm's meet gets
// BOTH conjuncts' rows. Declared rank `i + j` — boundedness needs
// `i >= 1` AND `j >= 1`, which is exactly `i > 0 and j > 0`. Under a
// single comparison this was outside-P; under one conjunct it would
// be unproven. Both rows discharge it.

import std/io
import std/spec

tor pair { i: i64, j: i64 }
| live { i: i64, j: i64 }
| done i64

tor run { } -> i64

pair = if(i > 0 and j > 0)
| then => live { i, j }
| else => done i

std/spec:claim(atom: terminates, on: pair) { "rank": "i + j" }

run = #L pair(i: 3, j: 5)
| live l |> @L(i: l.i - 1, j: l.j - 1)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
