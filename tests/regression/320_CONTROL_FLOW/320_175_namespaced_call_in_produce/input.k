// PIN (2026-10-05): a MODULE-PATH call inside a produce (`->`) expression
// is illegal like any other — `std/io` reads as a complete path atom to
// the expression parser's prefix mode, and the `:` truncated the parse
// before the call, so textContainsCall judged the text clean and the call
// leaked verbatim into emitted Zig (raw Stage-D error on
// `return libs/ogun:mesh.vert(...)` measured in armored-rail-ogun/rail).
// The admission wall now uses parseAll: TrailingGarbage routes the whole
// text to the raw scan, which judges `name(` as a call regardless.
import std/io

pub tor n { s: string } -> i64
n -> std/io:print.ln(s)

n(s: "x"): v |> std/io:print.ln("{{ v:d }}")
