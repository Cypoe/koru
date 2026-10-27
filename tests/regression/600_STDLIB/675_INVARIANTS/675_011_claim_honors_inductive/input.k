// The inductive hypothesis is load-bearing here: the guard `i < limit`
// bounds `i` from above only — nothing in it prevents `i` from being
// negative. `i >= 0` survives the `i+1` step ONLY because the goal
// itself is assumed at the current head. The entailment that proves it
// is the induction: `i >= 0 ∧ i < limit ∧ i' = i+1 ⊢ i' >= 0`.

import std/io
import std/spec

tor tick { i: i64, limit: i64 }
| live { i: i64, limit: i64 }
| done i64

tor run { } -> i64

tick = if(i < limit)
| then => live { i, limit }
| else => done i

std/spec:claim(atom: honors, on: tick) { "goal": "i >= 0" }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
