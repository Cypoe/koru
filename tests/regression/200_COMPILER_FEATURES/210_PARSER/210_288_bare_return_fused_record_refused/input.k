// PINS: a bare-return record produce written on one line without the comma —
// `-> { a: 1 b: 2 }` — refuses PARSE003 naming the fused field. The produce
// value is the same `{ name: value }` list struct_literal parses; its errors
// were swallowed by the bind-once pass and the text reached emitted Zig.
import std/io

pub tor f { a: i64 } -> { a: i64, b: i64 }
f -> { a: 1 b: 2 }
f(a: 4): r |> std/io:print.ln("{{ r.a:d }}")
