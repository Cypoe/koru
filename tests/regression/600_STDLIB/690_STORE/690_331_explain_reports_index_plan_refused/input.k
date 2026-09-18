// PINS: `koruc explain` reports a REFUSED index declaration with the
// transform's own wording. `std/indexes:store(players)` names no column —
// the declaration refuses at compile (same wall 690_329 pins), and the
// explainer's `status` row carries the identical refusal text rather than
// guessing a plan. The report for a refusing program is the diagnostic
// verbatim: one string, two sinks.

import std/store
import std/indexes
import std/io
import std/explain

std/store:new(players, capacity: 8) { key: i64 }
std/indexes:store(players)

std/io:print.ln("unreachable")
