// PINS: a braced branch payload whose second field's type runs into a
// third `name: type` on the same line (`b: i32 c: i32`, comma dropped)
// refuses PARSE003 at the declaration — the payload field list is held
// to the same missing-comma rule as every other `{ name: Type }` shape.
import std/io
tor check { x: i32 }
| high { a: i32, b: i32 c: i32 }
| low i32

check => high { a: x, b: 1, c: 2 }

check(x: 10)
| high h |> std/io:print.ln("{{ h.a:d }}")
| low _ |> _
