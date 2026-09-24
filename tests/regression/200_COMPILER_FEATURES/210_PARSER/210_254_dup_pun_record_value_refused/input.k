// PINS: a pun in a record expression binds its name — `{ a, ..., a: 2 }`
// binds `a` twice, same refusal as two explicit fields.
import std/io

tor f { a: i64 } -> { a: i64, y: i64 }
f -> { a, y: 1, a: 2 }

f(a: 1): r |> std/io:print.ln("{{ r.a:d }}")
