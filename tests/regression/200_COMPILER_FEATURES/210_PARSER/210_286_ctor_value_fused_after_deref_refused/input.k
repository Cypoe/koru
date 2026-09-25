// PINS: a constructor field value ending in `p.*` is a VALUE tail, not a
// type prefix — `{ a: p.* b: 2 }` fuses `b: 2` into `a`'s value. The
// fused-field boundary in struct_literal.fusedFieldLine exempts bare `*`
// prefix tokens (`*const mod:Type`), never a `*`-ending expression.
import std/io

tor f { p: *i64 }
| ok { a: i64, b: i64 }
| bad i64

f => ok { a: p.* b: 2 }

f(p: @ptrFromInt(0x1000))
| ok o |> std/io:print.ln("{{ o.a:d }}")
| bad _ |> _
