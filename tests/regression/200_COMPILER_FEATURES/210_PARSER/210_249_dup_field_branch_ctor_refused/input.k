// PINS: a field list takes each name once. `=> done { x: a, y: a, x: 2 }`
// constructs the field twice — the frontend accepted it and the backend died
// on `duplicate struct field name` in the emitted initializer; which value
// would have won is anybody's guess.
import std/io

tor f { a: i64 }
| done { x: i64, y: i64 }
| fail

f => done { x: a, y: a, x: 2 }

f(a: 1)
| done d |> std/io:print.ln("{{ d.x:d }} {{ d.y:d }}")
| fail |> std/io:print.ln("f")
