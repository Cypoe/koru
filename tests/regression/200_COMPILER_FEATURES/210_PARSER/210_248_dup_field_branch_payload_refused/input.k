// PINS: a field list takes each name once. `| done { x: i64, x: i64 }` declares
// the payload field twice — the frontend accepted it and the backend died on
// `duplicate struct member name 'x'` in the emitted union member.
import std/io

tor f { a: i64 }
| done { x: i64, x: i64 }
| fail

f => fail

f(a: 1)
| done _ |> std/io:print.ln("d")
| fail |> std/io:print.ln("f")
