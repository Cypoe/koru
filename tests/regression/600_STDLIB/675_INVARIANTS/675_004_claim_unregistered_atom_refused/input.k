// `atom:` is registered vocabulary, not arbitrary prose — an atom the
// registry does not name means nothing spec-side, so the claim means
// nothing. The refusal names the atom and points at the registry
// (the signal-vocabulary discipline: declare it in std/spec or drop it).

import std/spec

tor step { i: i64, limit: i64 } -> i64

step -> i

std/spec:claim(atom: settles-once, on: step) { "rank": "limit - i" }

step(i: 0, limit: 3)
