// The goal is one linear comparison — `splitLinCmp`'s grammar, the
// same one refine's relational atoms and the impl's guard read. A
// goal that is not a comparison is refused at declaration.

import std/spec

tor step { i: i64, limit: i64 } -> i64

step -> i

std/spec:claim(atom: honors, on: step) { "goal": "i limit" }

step(i: 0, limit: 3)
