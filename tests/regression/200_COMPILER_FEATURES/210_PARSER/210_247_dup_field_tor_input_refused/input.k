// PINS: a field list takes each name once. `tor f { x: i64, x: i64 }` declares
// the parameter twice — the frontend accepted it and the backend died on
// `duplicate struct member name 'x'` in emitted Zig, a symbol the author never
// wrote (measured 2026-09-24: `.{ .x = __koru_p_0, .x = __koru_p_1 }`).
// Declaration-side twin of PARSE009's call-site rule.
import std/io

tor f { x: i64, x: i64 } -> i64
f -> x

f(x: 1): r |> std/io:print.ln("{{ r:d }}")
