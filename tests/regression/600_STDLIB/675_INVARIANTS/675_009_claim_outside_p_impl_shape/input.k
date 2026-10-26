// A claim over a subject whose impl is not a single if-dispatch is
// `outside-P` — the prover names the constructor it cannot read rather
// than declining silently or guessing. The claim still stands declared;
// the judgment honestly routes it out of the decidable fragment.

import std/io
import std/spec

tor step { i: i64 } -> i64

step -> i

std/spec:claim(atom: terminates, on: step) { "rank": "i" }

step(i: 3): r |> std/io:print.ln("{{ r:d }}")
