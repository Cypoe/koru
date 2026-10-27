// The `!=` guard yields no linear rows — without declared types this
// fold is outside-P (675_017). But the field's own type `i & >=0` is
// both a rank candidate (`i`) and — under substitution — the produced
// value's contract `i' >= 0`, which discharges the bounded obligation
// outright. The type closes the hole the fence could not express.

import std/io
import std/spec

tor drop { i: i64 & >=0 }
| live i64
| done i64

tor run { } -> i64

drop = if(i != 0)
| then => live i
| else => done i

std/spec:claim(atom: terminates, on: drop) { }

run = #L drop(i: 3)
| live l |> @L(i: l - 1)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
