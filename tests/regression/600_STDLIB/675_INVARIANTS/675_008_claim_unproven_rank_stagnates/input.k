// A well-formed claim the prover cannot discharge is `unproven` — not a
// refusal, not a silent pass: the declared rank `i` GROWS across the
// back-edge, so the counterexample `R - R' <= 0` is feasible and the
// decrease entailment cannot be discharged. The program still compiles
// and runs — the claim routes to the guard lane — but the census names
// the judgment honestly.

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

std/spec:claim(atom: terminates, on: tick) { "rank": "i" }

run = #L tick(i: 0, limit: 3)
| live l |> @L(i: l.i + 1, l.limit)
| done d -> d

run(): r |> std/io:print.ln("{{ r:d }}")
