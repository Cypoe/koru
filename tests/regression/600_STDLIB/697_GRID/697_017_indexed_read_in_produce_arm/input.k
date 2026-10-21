// 697_017 — a grid read in a produce arm (`| then -> g[i].f`) is an
// `.expression` node, and the whole-program read lowering covers it like
// every other position an expression can stand in.
//
// `lowerCont` carries `.invocation` and `.inline_code`; a produce arm is
// neither — without `.expression` coverage the read reached the host
// verbatim as `g[i].v`, an undeclared identifier in Zig.
import std/io
import std/grid

std/grid:new(g, size: 8) { v: 0[i64] }
std/grid:stored { g[3].v: 42 }

pub tor peek { i: i64 } -> i64
peek = if(g[i].v == 42)
| then -> g[i].v + 1
| else -> 0

peek(i: 3): r
|> std/io:print.ln("{{ r:d }}")
