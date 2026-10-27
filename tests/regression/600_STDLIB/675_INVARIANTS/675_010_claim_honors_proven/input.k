// `honors` claims a fold invariant: the goal — a linear comparison over
// the subject's fields — holds at every fold head. The prover discharges
// it by induction: the `#L` entry's bindings establish the base (`i=0,
// limit=3` entails `i <= limit`), and at every `@L` back-edge the goal
// itself, as inductive hypothesis, joined with the producing arm's
// guard, entails the goal at the next head.

import std/io
import std/spec

tor tick { i: i64, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

tick = if(i < limit)
| then => live { i, limit }
| else => done i

std/spec:claim(atom: honors, on: tick) { "goal": "i <= limit" }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
