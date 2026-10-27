// Inference works for a decreasing fold too — guard `i > 0` normalizes
// to `-i < 0`, whose negation is the rank `i` — the same discharge,
// spelled by the guard rather than the author.

import std/io
import std/spec

tor tick { i: i64 }
| live i64
| done i64

tor run { } -> i64

tick = if(i > 0)
| then => live i
| else => done i

std/spec:claim(atom: terminates, on: tick) { }

run = #L tick(i: 3)
| live l |> @L(i: l - 1)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
