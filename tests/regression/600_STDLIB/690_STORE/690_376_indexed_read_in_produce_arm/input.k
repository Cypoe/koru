// 690_376 — an indexed read in a produce arm (`| then -> s[h].f`) is an
// `.expression` node, and the plural-store whole-program walk lowers it
// like every other position an expression can stand in.
//
// The plural walk carries `.invocation`, `.inline_code`, and
// `.branch_constructor`; a produce arm is none of those — without
// `.expression` coverage the read reached the host verbatim as
// `arena[h].item`, an undeclared identifier in Zig. The identity-store
// walk carries the arm already (110_022); this is its plural twin.
import std/io
import std/store

std/store:new(arena, capacity: 8) { item: i64 }

pub tor peek { h: i64 } -> i64
peek = if(arena[h].item > 0)
| then -> arena[h].item + 1
| else -> 0

std/store:insert(arena) { item: 7 }
| row a |> peek(h: a): r
    |> std/io:print.ln("{{ r:d }}")
