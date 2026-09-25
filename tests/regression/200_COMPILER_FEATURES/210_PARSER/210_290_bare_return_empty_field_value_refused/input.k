// PINS: a typeless/valueless entry in a bare-return record produce —
// `-> { a: 1, b: }` — refuses PARSE003. An empty field value emits `.b = ` in
// Zig; the refusal names the malformed field at the authored line.
import std/io

pub tor f { a: i64 } -> { a: i64, b: i64 }
f -> { a: 1, b: }
f(a: 4): r |> std/io:print.ln("{{ r.a:d }}")
