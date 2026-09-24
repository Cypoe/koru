// LEGAL SIBLING of the 210_247-251 pins: every surface the one-name rule
// guards, spelled with distinct names, must still compile and run.
import std/io

tor f { a: i64, b: i64 }
| done { x: i64, y: i64 }
| fail

tor g { a: i64 } -> { x: i64, y: i64 }
g -> { x: a, y: a }

f => done { x: a, y: b }

f(a: 1, b: 2)
| done d |> std/io:print.ln("{{ d.x:d }} {{ d.y:d }}")
| fail |> std/io:print.ln("f")

g(a: 3): r |> std/io:print.ln("{{ r.x:d }} {{ r.y:d }}")
