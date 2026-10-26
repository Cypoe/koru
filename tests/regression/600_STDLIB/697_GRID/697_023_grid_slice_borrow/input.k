// PINS: `std/grid:slice(name) { grid.field }` — borrows a column's backing
// array as a raw slice. Reads `s[i]` are generic indexing (they splice
// verbatim — no __koru_at call, no field access). Writes `stored { s[i]:
// v }` emit a direct `s[i] = v` assignment — the grid's per-access floor
// is dropped by the borrow's own contract: the program asked for the raw
// view, so index obligations move to the program. The value is still
// typed by the borrowed column's declared type.
//
//   std/grid:new(g, size: 4) { c: 0[u8] }
//   std/grid:slice(s) { g.c }
//
// Value oracle: fill 10,11,12,13 through the borrow; read s[0]=10,
// s[3]=13, s.len=4 back.

import std/io
import std/grid

std/grid:new(g, size: 4) { c: 0[u8] }
std/grid:slice(s) { g.c }

std/grid:stored { s[0]: 10, s[1]: 11, s[2]: 12, s[3]: 13 }
|> std/io:print.ln("a={{ s[0]:d }} b={{ s[3]:d }} len={{ s.len:d }}")
