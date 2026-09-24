// PINS: a field list takes each name once. `-> { x: i64, x: i64 }` is a record
// TYPE STRING, not a Shape — the dup only surfaced when the emitter pasted it
// into a Zig struct (`duplicate struct field name`). Same one-name rule, one
// more surface.
import std/io

tor f { a: i64 } -> { x: i64, x: i64 }
f -> { x: a, x: a }

f(a: 1): r |> std/io:print.ln("{{ r.x:d }}")
