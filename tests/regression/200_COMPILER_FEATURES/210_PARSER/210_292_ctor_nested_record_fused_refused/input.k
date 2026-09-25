// PINS: a nested record literal inside a constructor field —
// `=> ok { inner: { a: x b: x }, z: 1 }` — refuses PARSE003 naming the fused
// inner field. The outer field's value is itself a `{ name: value }` list;
// the same parser checks it.
import std/io

tor f { a: i64 }
| ok { inner: { a: i64, b: i64 }, z: i64 }
| bad i64

f => ok { inner: { a: a b: a }, z: 1 }

f(a: 4)
| ok o |> std/io:print.ln("{{ o.z:d }}")
| bad _ |> _
