// PINS: a store:new seed line whose value is a typed literal `0[i64]` fused
// with the next column refuses KORU161 naming the missing comma. `0[i64]`
// ends `]` but is a value annotation, not a `[`-led type prefix — the
// fusedFieldLine exemption does not apply to it.
import std/io
import std/store

std/store:new(tasks, capacity: 4) { n: 0[i64] m: 0[i64] }

std/io:print.ln("unreachable")
