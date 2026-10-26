// `on:` resolves the way an invocation path does — a claim on nothing is
// a lie, and a claim on two things is a guess. A subject that names no
// declared tor refuses, naming the subject it could not find.

import std/spec

tor step { i: i64, limit: i64 } -> i64

step -> i

std/spec:claim(atom: terminates, on: no-such-tor) { "rank": "limit - i" }

step(i: 0, limit: 3)
