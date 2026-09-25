// PINS: a nameless entry in a branch constructor — `=> ok { a: 1, : 2 }` —
// refuses PARSE003 at the constructor line. An empty field name emits `. = 2`
// in Zig; the constructor field loop refuses it before emit.
import std/io

tor f { a: i64 }
| ok { a: i64, b: i64 }
| bad i64

f => ok { a: 1, : 2 }

f(a: 1)
| ok o |> std/io:print.ln("{{ o.a:d }}")
| bad _ |> _
