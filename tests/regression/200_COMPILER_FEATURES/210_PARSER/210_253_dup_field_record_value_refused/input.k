// PINS: a record EXPRESSION in value position is a binding list — `x` twice
// silently dropped one value at emit time (the backend died on
// `duplicate struct field name`). Same one-name rule as PARSE009/PARSE010.
import std/io

tor f { a: i64 } -> { x: i64, y: i64 }
f -> { x: a, y: 1, x: 2 }

f(a: 1): r |> std/io:print.ln("{{ r.x:d }}")
