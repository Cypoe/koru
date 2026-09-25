// PINS: a missing comma between two fields written on ONE line —
// `=> ok { a: 1 b: 2 }` — refuses PARSE003 naming the fused field, not a
// Zig `expected ',' after initializer` in emitted code. The boundary
// detector is struct_literal.fusedFieldLine: whitespace + `ident:` at
// depth 0 inside a field value is always a second field that lost its
// comma. Every consumer inherits: capture seeds (KORU164), store:new
// seeds (KORU161), ctor payloads, inline record field types (PARSE003),
// and `-> { a: i64 b: i64 }` record returns name MissingComma instead of
// "single field".
import std/io

tor read { path: string }
| ok { a: i32, b: u8 }
| err string

read => ok { a: 1 b: 2 }

read(path: "x")
| ok o |> std/io:print.ln("{{ o.a:d }}{{ o.b:d }}")
| err _ |> _
