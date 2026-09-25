// Legal sibling of the fused-field refusals (210_285/286/288/291/292/294):
// a field value whose last token is `]`-closed (`xs[i]`, a typed literal
// `0[i64]`) or `*`-closed (`p.*`) is a VALUE tail, not a type prefix — with
// the comma present these are ordinary fields, and the record literal they
// sit in must compile and run unchanged. The type-prefix exemption in
// struct_literal.fusedFieldLine covers `[`-led and `const`-led tokens only.
import std/io

tor pick { xs: [4]i64, i: i64 }
| ok { a: i64, b: i64 }
| bad i64

pick => ok { a: xs[i], b: 2 }

pub tor sum { p: { a: i64, b: i64 } }
| done i64
| bad i64

sum => done p.a + p.b

pub tor make { seed: i64 } -> { a: i64, b: i64 }
make -> { a: seed, b: seed * 2 }

pick(xs: [4]i64{1,2,3,4}, i: 2)
| ok o |> std/io:print.ln("{{ o.a:d }}{{ o.b:d }}")
| bad _ |> _

sum(p: { a: 3, b: 4 })
| done d |> std/io:print.ln("{{ d:d }}")
| bad _ |> _

make(seed: 5): m |> std/io:print.ln("{{ m.a:d }}{{ m.b:d }}")
