// A goal the step cannot preserve: `i < limit` at the head, but the
// back-edge steps `i` by one — from `i = limit - 1` the next head has
// `i = limit`, and `i < limit` fails. The base holds (0 < 3); the
// induction does not — `unproven` names the arm whose edge admits the
// countermodel.

import std/io
import std/spec
import std/witness

tor tick { i: i64, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

tick = if(i < limit)
| then => live { i, limit }
| else => done i

std/witness:enforce { }

std/spec:claim(atom: honors, on: tick) { "goal": "i < limit" }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
