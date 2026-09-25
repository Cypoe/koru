// PINS: a nameless entry in a bare-return record produce — `-> { a: 1, : 2 }` —
// refuses PARSE003. A field with no name parses to an empty name in the shared
// parser and emits `. = 2` in Zig; the refusal names the malformed field at
// the authored line.
import std/io

pub tor f { a: i64 } -> { a: i64, b: i64 }
f -> { a: 1, : 2 }
f(a: 4): r |> std/io:print.ln("{{ r.a:d }}")
