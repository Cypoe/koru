// PINS: ImmediateImpl.location names the `name ->` head line. A refusal
// that reads it raw — here KORU021, a bare return cannot construct a
// branch of a tor that declares them — lands its caret on the author's
// impl line.
import std/io

tor f { a: i64 }
| done { x: i64, y: i64 }
| fail

f -> a

f(a: 1)
| done d |> std/io:print.ln("{{ d.x:d }} {{ d.y:d }}")
| fail |> std/io:print.ln("f")
