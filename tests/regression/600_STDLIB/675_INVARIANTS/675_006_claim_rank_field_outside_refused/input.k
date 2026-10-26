// The rank function measures the subject tor's own state — a name that is
// not an input field of `on:` cannot be a rank over that tor. The refusal
// names the stray field, the rank it rode in on, and the subject.

import std/spec

tor step { i: i64, limit: i64 } -> i64

step -> i

std/spec:claim(atom: terminates, on: step) { "rank": "limit - nosuch" }

step(i: 0, limit: 3)
