// PINS: a constructor field value ending in an index `xs[i]` is a VALUE tail,
// not a type prefix — `{ a: xs[i] b: 2 }` fuses `b: 2` into `a`'s value for
// want of a comma, and the boundary detector must see it. The type-prefix
// exemption in struct_literal.fusedFieldLine covers `[`-led tokens (`[]`,
// `[N]`, `[]const`) only; a `]`-closed token that starts with a name is
// indexing, and `ident:` after it is a second field.
import std/io

tor f { xs: [4]i64, i: i64 }
| ok { a: i64, b: i64 }
| bad i64

f => ok { a: xs[i] b: 2 }

f(xs: [4]i64{1,2,3,4}, i: 0)
| ok o |> std/io:print.ln("{{ o.a:d }}")
| bad _ |> _
