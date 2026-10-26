// PINS: the sweep's own cursor indexes the grid WITHOUT the index floor.
//
//   std/grid:sweep(cells) ! sweep c |> std/grid:stored { c.v: c.v + 1 }
//
// The loop the sweep emits constructs the index from `0..__koru_size`, so the
// `__koru_at` call the shared lowering wraps around it re-proves a fact the
// transform already holds. The cursor rides the lowering as a TRUSTED index
// — the same widening + cast, spelled through `__koru_intcast` so no
// `llvm.assume` reaches the vectorizer — with the failure edge gone.
//
// Two directions are pinned, in post.sh: `__koru_at` never receives the
// cursor, and the SAME program's ordinary `cells[i]` under `for` keeps the
// floor — trusted is a property of the name's provenance, not a widening of
// `unsafe(bounds)`.
//
// The value oracle: cells starts [0,10,20,0], the sweep adds 1 to every
// visited cell, the for-loop sums: 1 + 11 + 21 + 1 = 34.
import std/io
import std/grid

std/grid:new(cells, size: 4) { v: 0[i64] }
std/grid:stored { cells[1].v: 10 }
std/grid:stored { cells[2].v: 20 }

std/grid:sweep(cells)
! sweep c |> std/grid:stored { c.v: c.v + 1 }

capture { sum: 0[i64] }
! as s |> for(0..4)
    ! each i |> captured { sum: s.sum + cells[i].v }
| captured r |> std/io:print.ln("{{ r.sum:d }}")
