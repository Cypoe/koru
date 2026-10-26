// PINS: `0[<grid>]` — a field typed by a grid's own name is an INDEX INTO
// THAT GRID. The declaring name is the type: `nd: 0[tn]` means "a cell
// holding an index into tn", emitted as the narrowest unsigned integer
// covering tn's extent, bound-checked ONCE at the write (the panic edge
// moves to insertion), certified at every read of tn through it — the
// floor check a `tn[x]` pays does not re-run on an index the grid itself
// vouches for.
//
//   std/grid:new(tn, size: 256) { fc: 0[tn], v: 0[i64] }
//   std/grid:new(que, size: 8)  { nd: 0[tn] }
//
//   tn[que[i].nd]  — que.nd is tn-typed: the value entered through a
//   checked write, so the read needs no floor (emits __koru_intcast,
//   never __koru_at).
//
// Self-reference is the common shape: tn.fc: 0[tn] is an index into tn's
// own cells — link fields of a graph or trie.
//
// Value oracle: tn[0].fc=1, tn[1].v=42, tn[1].fc=7, que[0].nd=1,
// que[1].nd=tn[0].fc (=1). Reads: tn[que[0].nd].v=42,
// tn[que[0].nd].fc=7, tn[que[1].nd].v=42 again.
//
// Arithmetic drops the proof: `tn[que[0].nd + 1]` is tn[2].v=0 — the same
// field read plus `+ 1` keeps the __koru_at floor, because the check was
// about the cell's contents, not about arithmetic on them.

import std/io
import std/grid

std/grid:new(tn, size: 256) { fc: 0[tn], v: 0[i64] }
std/grid:new(que, size: 8) { nd: 0[tn] }

std/grid:stored { tn[0].fc: 1, tn[1].v: 42, tn[1].fc: 7, que[0].nd: 1 }
|> std/grid:stored { que[1].nd: tn[0].fc }
|> std/io:print.ln("v={{ tn[que[0].nd].v:d }} fc={{ tn[que[0].nd].fc:d }} again={{ tn[que[1].nd].v:d }} arith={{ tn[que[0].nd + 1].v:d }}")
