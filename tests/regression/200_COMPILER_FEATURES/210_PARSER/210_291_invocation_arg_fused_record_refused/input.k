// PINS: a record literal carried by an invocation argument —
// `f(p: { a: 1 b: 2 })` — refuses PARSE003 naming the fused field. Argument
// values are record literals the emitter lowers with emitStructLiteral; the
// field list is parsed by struct_literal and its errors must surface.
import std/io

pub tor f { p: { a: i64, b: i64 } }
| done i64
| bad i64

f => done p.a + p.b

f(p: { a: 1 b: 2 })
| done d |> std/io:print.ln("{{ d:d }}")
| bad _ |> _
